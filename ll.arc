(each x '("urlencode0.arc" "between0.arc" "parsecomb0.arc" "tojson0.arc" "fromjson0.arc") (load (+ "lib/" x)))

(mac page (title cssname jsname . body)
  `(do (gendoctype)
       (tag (html xmlns "http://www.w3.org/1999/xhtml") 
         (tag (head) 
           (tag (title) (pr ,title))
           (tag (link rel "stylesheet" type "text/css" href ,cssname) (pr ""))
           (each x '(,@jsname) (tag (script type "application/javascript" src x))))
         (tag (body)
           ,@body))))

(= players* (table))
(= characters* (table))
(= cabals* (table))

(= (players* 'test) (obj name 'test password 'password))

;initial-div
;request
;response

(mac login-header ()
  `(tag (div class "login")
   (if (tag (a href "#" onclick "ShowLogin()") (pr "Log in"))
   (tag (fieldset id "signing_menu" class "common-form")
     (tag (form method "post" id "signin" action "http://localhost:8080/sessions")
       (tag (p) (tag (label for "u")(pr "Username"))
       (tag (input type "text" id "u" name "u" value "" title "u")))       
       (tag (p) (tag (label for "p")(pr "Password"))
       (tag (input type "password" id "p" name "p" value "" title "p")))
       (tag (p class "remember") (tag (input type "submit" id "signin-submit" value "Sign in"))
       (tag (input type "checkbox" id "remember" name "remember_me" value "1"))
       (tag (label for "remember") (pr "Remember me")))
     )
   ))))

(mac character-header ()
  `(tag (div)(w/rlink (do (logout-user get-user.req) "index.html") (pr (+ "Log out " get-user.req)))))

(mac header ()
  `(tag (p class "blue") (pr " ") (tag (span) (tag (a href "about")(pr "About")) (tag (a href "rules")(pr "House Rules")) (tag (div class "header")(if (get-user req) (character-header)
                                (login-header))))))
(defop || req (page "Ascension Auckland" "style.css" ("jquery-1.3.2.js" "standard.js") (tag (div) (header) (tag h1 (pr "Nexus")) (tag (div)(tag (img class "logo" src "NexusLogo.png"))))))

(defopr index.html req #\/)

(= actionsdone* (table))
; format order date type data
; order can be used as a uuid; it is monotonically increasing
(= actionqueue* (table))
(= uuid2order* (table))
(= order2uuid* (table))
; format uuid date type data
(= uuidtop* 0)
(= ordertop* 0)
(def addaction (ty da)
  (do
    (= (order2uuid* (++ ordertop*)) (++ uuidtop*))
    (= (uuid2order* uuidtop*) ordertop*)
    (= (actionqueue* uuidtop*) (obj "order" ordertop* "date" "future" "type" ty "data" da))
  ))

(defop addaction req
  (do
    (addaction (arg req "ty") (arg req "da"))
    pr req))

(defop showactions req
  (tojson actionqueue*))

; format {...,ord: {ty: name, da: data}, ...}
(def parse-actions (json-data)
  ;assume this has been sanitized
  (do
    (= uuidtop* 0)
    (= ordertop* 0)
    (= actionqueue* (table))
    (= uuid2order* (table))
    (= order2uuid* (table))
    (let parsed-data (fromjson json-data)
      ((for x 0 (len parsed-data)
        (addaction (parsed-data.x "ty") (parsed_data.x "da")))))
  ))
(defop aq req
  ())

(def make-reader ()
  ())

(def make-writer ()
  ())

(mac defc ()
  ())

(load-userinfo)
(create-acct "foo" "foot")

(defopr sessions req
  (login-handler req 'login (list (fn (a b) "index.html") "index.html")))

(def actions (req)
  (tag (div class "actions")
    (tag (div class "deadactions"))
    (tag (div class "liveactions"))
  ))

(thread:serve 8080)
