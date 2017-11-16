;;; ivy-feedwrangler.el --- An Ivy interface to the Feedwrangler RSS service
;; -*- lexical-binding: t; -*-

;; Adam Simpson <adam@adamsimpson.net>
;; Version: 0.2.2
;; Package-Requires: ((emacs "25") (ivy "0.9") (let-alist "1.0.5"))
;; Keywords: news, rss, url, ivy
;; URL: https://github.com/asimpson/ivy-feedwrangler

;;; Commentary:
;; This package requires that you manually retrieve your access token by using the curl command on this page: https://feedwrangler.net/developers/users
;; Once you have an access token add your credentials to your authinfo file with the following fields:
;; machine: feedwrangler.net
;; login: account email address
;; password: token

;;; Code:

(require 'ivy)
(require 'json)


(defvar ivy-feedwrangler--base-url
  "https://feedwrangler.net/api/v2/feed_items/"
  "The base URL for the API.")

(defvar ivy-feedwrangler--current-link
  nil
  "The href to the post in ‘ivy-feedwrangler--post-buffer’.")

(defvar ivy-feedwrangler--post-buffer
  "feedwrangler-body"
  "The buffer to read posts.")

(defun ivy-feedwrangler--parse-feed(feed)
  "Return FEED items in format: 'Site Title - Post title' format."
  (mapcar (lambda (x)
            (let-alist x
              (cons (format "%s - %s" .feed_name  .title)
                    (list :url .url :id .feed_item_id :body .body))))
          feed))

(defun ivy-feedwrangler--get-token()
  "Return the feedrwrangler token from auth-source."
  (let ((entry (auth-source-search :host "feedwrangler.net" :max 1)))
    (funcall (plist-get (car entry) :secret))))

(defun ivy-feedwrangler--mark-read(&optional id mark-all)
  (let (url (token (ivy-feedwrangler--get-token)))
    (if (and (null mark-all) id)
        (setq url (concat ivy-feedwrangler--base-url "update?access_token=" token "&feed_item_id=" id "&read=true"))
      (setq url (concat ivy-feedwrangler--base-url "mark_all_read?access_token=" token)))
    (url-retrieve-synchronously url t)))

(defun ivy-feedwrangler--get-feed()
  "Make http request for feed items and parse JSON response."
  (let* ((token (ivy-feedwrangler--get-token))
         (url (concat ivy-feedwrangler--base-url "list?access_token=" token "&read=false"))
         (buf (url-retrieve-synchronously url t)))
    (json-read-from-string (with-current-buffer buf
                             (buffer-substring-no-properties
                              (marker-position url-http-end-of-headers)
                              (point-max))))))

;;;###autoload
(defun ivy-feedwrangler()
  "Get latest items from feedwrangler."
  (interactive)
  (message "Loading feed...")
  (let ((feed (ivy-feedwrangler--parse-feed (alist-get 'feed_items (ivy-feedwrangler--get-feed)))))
    (if (null feed)
        (message "No new unread items")
      (ivy-read "Unread items: "
                feed
                :action (lambda (item)
                          (let ((url (plist-get (cdr item) :url)))
                            (if (memq system-type '(darwin))
                                (start-process (concat "ivy-feedwrangler-" url) nil "open" url "-g")
                              (browse-url url))))))))

(ivy-set-actions
 'ivy-feedwrangler
 '(("x" (lambda (item)
          (let ((id (number-to-string (plist-get (cdr item) :id))))
            (ivy-feedwrangler--mark-read id nil)) "Mark as Read"))
   ("X" (lambda (item)
          (ivy-feedwrangler--mark-read nil t)) "Mark as Read")
   ("p" (lambda (item)
          (let ( (body (plist-get (cdr item) :body))
                 (url (plist-get (cdr item) :url)))
            (when (get-buffer ivy-feedwrangler--post-buffer) (kill-buffer ivy-feedwrangler--post-buffer))
            (setq ivy-feedwrangler--current-link url)
            (with-current-buffer (get-buffer-create ivy-feedwrangler--post-buffer)
              (insert body)
              (shr-render-buffer ivy-feedwrangler--post-buffer)))) "View Post")))

(provide 'ivy-feedwrangler)

;;; ivy-feedwrangler.el ends here
