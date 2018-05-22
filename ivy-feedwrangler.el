;;; ivy-feedwrangler.el --- An Ivy interface to the Feedwrangler RSS service
;; -*- lexical-binding: t; -*-

;; Adam Simpson <adam@adamsimpson.net>
;; Version: 0.2.6
;; Package-Requires: ((ivy "9.0"))
;; Keywords: rss, url, ivy
;; URL: https://github.com/asimpson/ivy-feedwrangler

;;; Commentary:
;; This package requires that you manually retrieve your access token by using the curl command on this page: https://feedwrangler.net/developers/users
;; Once you have an access token add your credentials to your authinfo file with the following fields:
;; machine: feedwrangler.net
;; login: account email address
;; password: token

;;; Code:
(require 'ivy)
(require 'url)
(require 'shr)

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
  "Returns feed items in format: 'Site Title - Post title' format."
  (mapcar (lambda (x)
            (cons (string-trim (format "%s - %s" (alist-get 'feed_name x) (decode-coding-string (alist-get 'title x) 'utf-8)))
                  (list :url (alist-get 'url x)
                        :title (alist-get 'title x)
                        :id (alist-get 'feed_item_id x)
                        :body (alist-get 'body x)))) feed))

(defun ivy-feedwrangler--get-token()
  "Returns the feedrwrangler token from auth-source."
  (let ((entry (auth-source-search :host "feedwrangler.net" :max 1)))
    (funcall (plist-get (car entry) :secret))))

(defun ivy-feedwrangler--mark-read(&optional id mark-all)
  "Marks a single item as read if passed an optional ID.
With optional mark-all mark all unread items as read."
  (let (url (token (ivy-feedwrangler--get-token)))
    (if (and (null mark-all) id)
        (setq url (concat ivy-feedwrangler--base-url "update?access_token=" token "&feed_item_id=" id "&read=true"))
      (setq url (concat ivy-feedwrangler--base-url "mark_all_read?access_token=" token)))
    (url-retrieve-synchronously url t)))

(defun ivy-feedwrangler--get-feed()
  "Make http request for feed items and parse JSON response"
  (let* ((token (ivy-feedwrangler--get-token))
         (url (concat ivy-feedwrangler--base-url "list?access_token=" token "&read=false"))
         (buf (url-retrieve-synchronously url t)))
    (json-read-from-string (with-current-buffer buf (buffer-substring-no-properties
                                                     (marker-position url-http-end-of-headers)
                                                     (point-max))))))
(defun ivy-feedwrangler--fetch-pinboard-token()
  "Returns the pinboard API token from auth-source."
  (let ((entry (auth-source-search :host "pinboard.in" :max 1)))
    (funcall (plist-get (car entry) :secret))))

;;;###autoload
(defun ivy-feedwrangler()
  "Get latest items from feedwrangler."
  (interactive)
  (message "Loading feed...")
  (let (feed)
    (setq feed (ivy-feedwrangler--parse-feed (alist-get 'feed_items (ivy-feedwrangler--get-feed))))
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
            (ivy-feedwrangler--mark-read id nil))) "Mark item as read")
   ("X" (lambda (item)
          (ivy-feedwrangler--mark-read nil t)) "Mark all as read")
   ("r" (lambda (item)
          (url-retrieve-synchronously (concat "https://api.pinboard.in/v1/posts/add?auth_token="
                                              (ivy-feedwrangler--fetch-pinboard-token)
                                              "&url="
                                              (plist-get (cdr item) :url)
                                              "&description="
                                              (plist-get (cdr item) :title)
                                              "&toread=yes"))) "Save as unread in pinboard")
   ("p" (lambda (item)
          (let ( (body (plist-get (cdr item) :body))
                 (url (plist-get (cdr item) :url)))
            (when (get-buffer ivy-feedwrangler--post-buffer) (kill-buffer ivy-feedwrangler--post-buffer))
            (setq ivy-feedwrangler--current-link url)
            (with-current-buffer (get-buffer-create ivy-feedwrangler--post-buffer)
              (insert body)
              (shr-render-buffer ivy-feedwrangler--post-buffer)))) "View post")))

(provide 'ivy-feedwrangler)

;;; ivy-feedwrangler.el ends here
