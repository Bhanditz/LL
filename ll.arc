(each x '("ac1.arc" "urlencode0.arc" "between0.arc" "parsecomb0.arc" "tojson0.arc" "fromjson0.arc" "fileutils.arc") (load (+ "lib/" x)))
(each x '("files.arc" "http.arc" "web.arc") (load x))

(= hpwfile*   "secret/hpw"
   adminfile* "secret/admin")

(if (file-exists "secret-found")
  (load "secret/restore.arc")
  (do (load "secret/first-run.arc")
      (system "touch secret-found")))

;(def get-user (req) 
;  (let u (aand (alref car.req!cooks "user") (cookie->user* (sym it)))
;    (when u (= (logins* u) car.req!ip))
;    u))

(mac defpathr (path1 path2 vars . body)
   `(defpath-raw ,path1 ,vars
       (do ,@body
           (redirect ',path2))))

(mac defpathtext (path vars . body)
  `(defpath-raw ,path ,vars
     (resphead http-ok+ (copy httpd-hds* "Content-Type" "text/plain"))
     ,@body))

(mac defpathjson (path vars . body)
  `(defpath-raw ,path ,vars
     (resphead http-ok+ (copy httpd-hds* "Content-Type" "text/json"))
     ,@body))

(mac defpathl (path vars . body)
  `(defpath ,path ,vars
     (if (get-user ,@vars)
       (do ,@body)
       (login-page 'login "You must log in to view this page." (list "" ',path)))))

;redefine ensure-dir here for the moment
(def ensure-dir (path)
  (unless (dir-exists path)
    (makepath nil ((ac-scheme regexp-split) "/" path))))

(def vcpull ()
  (if (dir-exists "vcstatic")
    (system "cd vcstatic && git pull") 
    (system "git clone git://github.com/flaviusb/vcstatic.git")))
(vcpull)
(defpath /force-update (req)
  (+ (gendoctype)
     (tag html (tag body (vcpull)))))

(defpath /showheaders (req)
  (+ (gendoctype)
     (tag html (tag body (disp req)))))


(mac page (title cssname jsname . body)
  `(do (gendoctype)
       (tag (html xmlns "http://www.w3.org/1999/xhtml") 
         (tag (head) 
           (tag (title) (pr ,title))
           (tag (link rel "stylesheet" type "text/css" href ,cssname) (pr ""))
           (each x '(,@jsname) (tag (script type "application/javascript" src x)))
             (gentag meta http-equiv "content-type" content "application/xhtml+xml; charset=utf-8"))
         (tag (body)
           ,@body))))


(= characters* (table))
(= cabals* (table))

;initial-div
;request
;response

(mac login-header ((o prefix ""))
  `(tag (li class "login menu")
   (tag (a href "#" onclick "ShowLogin()") (pr "Log in"))
   (tag (fieldset id "signin_menu" class "hid cf cfi")
     (tag (form method "post" id "signin" action ,(+ prefix "sessions"))
       (tag (p) (tag (label for "u")(pr "Username"))
       (tag (input type "text" id "u" name "u" value "" title "u")))       
       (tag (p) (tag (label for "p")(pr "Password"))
       (tag (input type "password" id "p" name "p" value "" title "p")))
       (tag (p class "remember") (tag (input type "submit" id "signin-submit" value "Sign in"))
       (tag (input type "checkbox" id "remember" name "remember_me" value "1"))
       (tag (label for "remember") (pr "Remember me")))
     )
   )))

(mac navit (loc text)
  `(tag (li class "menu") (tag (a href ,(string loc)) (pr ,(string text)))))

(mac popupmenu (id outer inner) `(tag (li class "menu") ,outer (tag (ul class "menu mf") ,inner) ))

(defpathr /logout / (req)
  (logout-user get-user.req))

(mac character-header ((o prefix ""))
  `(do (navit ,(+ prefix "aq") "Action Queue") (navit ,(+ prefix "cs") "Character Sheet") (tag (li class "right-align") (tag (a href ,(+ prefix "logout")) (pr "Log out " get-user.req)))))
;  `(tag (div)(tag (a href "aq")(pr "Action Queue"))(pr " ")(tag (a href "cs")(pr "Character Sheet"))(pr " ")(w/rlink (do (logout-user get-user.req) "index.html") (pr (+ "Log out " get-user.req)))))

(mac header ((o prefix ""))
  `(tag (nav) (tag (ul class "menu") (tag (li class "img") (tag (a href ,(+ prefix "index.html")) (tag (img src ,(+ prefix "s/SkullTiny.png"))))) 
     (popupmenu "OOC" (tag (a href "#") (pr "OOC"))(+ (navit ,(+ prefix "vc/about") "About") (navit ,(+ prefix "vc/rules") "House Rules") (navit ,(+ prefix "vc/gamelocations") "Game Dates and Locations")))
     (popupmenu "IC" (tag (a href "#") (pr "IC")) (+ (navit ,(+ prefix "vc/timeline") "Timeline") (navit ,(+ prefix "vc/setting") "Setting") (navit ,(+ prefix "vc/cabals") "Cabals")))
     (if (and (~is req nil) (get-user req))
       (character-header ,prefix)
       (login-header ,prefix)))))
(defpath / (req) (page "Ascension Auckland" "s/style.css" ("s/jquery-1.4.2.min.js" "s/standard.js") (+ (tag header (tag h1 (pr "Nexus"))) (header) (tag (img class "logo" src "s/NexusLogo.png")))))

(defpathr /index.html / (req) nil)

(def eschr (chr)
  (case chr   #\<        "&#60;" 
              #\>        "&#62;"
              #\"        "&#34;"
              #\'        "&#39;"
              #\&        "&#38;"
              #\newline  "<br />\n"
                         chr))

(def escid (str)
  (tostring 
    (each chr str
      (pr (case chr
             #\:  "\\\\:"
             #\.  "\\\\."
             #\   "_"
                  chr)))))

(def escidm (str)
  (tostring 
    (each chr str
      (pr (case chr
             #\   "_"
                  chr)))))

; Because of stdlib limitations, we cannot get file modification time in a platform portable way
; Instead, we explicitly flush the cache, and otherwise just use the existing file
; As the 'cache' is rev + processing -> temp file with rev identifier, the main reason to flush
; the 'cache' is when the processing method changes
(def cacheize (file name proc (o revi nil))
  (do
    (if (is revi nil) (= revi (cut (readline:pipe-from:string "git log " file) 7)))
    (let fl (+ "../static-cache/" revi ":" name)
      (if (file-exists fl)
          (w/infile i fl
            (whilet b (readc i)
              (writec b)))
          (w/outfile fo fl
              (let fi (pipe-from:string "git show " revi ":" file)
                (let str proc.fi
                  (do (close fi)
                      (disp str fo)
                      (disp str)))))))))

(def lamecache (file proc)
  (let fl (+ "../static-cache/" file)
    (if (file-exists fl)
      (w/infile i fl
        (whilet b (readc i)
          (writec b)))
      (w/outfile fo fl
        (let str proc.file
          (do (disp str fo)
              (disp str)))))))

(def clear-cache-directories ()
  (each x cachedirs* (do (rm-rf x) (mkdir x))))

(def shellesc (str)
  ((ac-scheme regexp-replace*) "([\"])" str "\\\\"))

(def textize (fi)
    (with (temp "" pipe nil acc "")
      (do (whilet li readc.fi (= temp (+ temp li)))
          (= pipe (pipe-from:string  "echo \"" shellesc.temp "\" | markdown -T "))
          (whilet lj readc.pipe (= acc (+ acc lj)))
          (close pipe)
          acc)))

(def mustacheize (fi)
    (with (temp "" pipe nil acc "")
      (do ;(whilet li readc.fi (= temp (+ temp li)))
          (= pipe (pipe-from:string  "mustache " fi ".yml " fi ".mustache"))
          (whilet lj readc.pipe (= acc (+ acc lj)))
          (close pipe)
          acc)))

(defpath /vc/: (req doc)
  (if (file-exists (string "vcstatic/" doc ".text"))
    (page "Ascension Auckland" "../s/style.css" ("../s/jquery-1.4.2.min.js" "../s/standard.js")
      (+
        (tag header (tag h1 (pr "Nexus")))
        (header "../")
        (tag (section class "generated-text") (w/cd "vcstatic" (cacheize (+ doc ".text") (+ doc ".html") textize)))))
    (if (file-exists (string "vcstatic/" doc ".mustache"))
      (page "Ascension Auckland" "../s/style.css" ("../s/jquery-1.4.2.min.js" "../s/standard.js")
        (+
          (tag header (tag h1 (pr "Nexus")))
          (header "../")
          (tag (section class "generated-text") (w/cd "vcstatic" (lamecache doc mustacheize)))))
      (page "Document Not Found" "../s/style.css" ("../s/jquery-1.4.2.min.js" "../s/standard.js") (+ "Document " doc " not found.")))))

;(= actionsdone* (table))
; per user; [pending, held, done, future], personal, retainer - [by ref], ally - [by fnidish]

; set - called zf to avoid name collisions
(def zf ()
  (obj values (table) indices (table)))

(def zfill fill
    (let it (zf)
       (each x fill
         (insert it x))
       it))
(def zfilll (fill)
    (let it (zf)
      (each x fill
        (insert it x))
      it))
(def insert (zfs val)
  (do (if (is zfs nil) (= zfs (zf)))
      (= (zfs!values (+ (len zfs!indices) 1)) val)
      (= zfs!indices.val (+ (len zfs!indices) 1))
      zfs))
(def remove (zfs val)
  (do 
    (if (is zfs nil) (= zfs (zf))
      (if (~is zfs!indices.val nil)
        (do
            (with (pivot zfs!indices.val length (len zfs!indices))
                  (for x pivot length
                    (do (= zfs!values.x (zfs!values (+ x 1)))
                        (unless (is zfs!values.x nil) (= (zfs!indices zfs!values.x) x)))))
            (= zfs!indices.val nil))))
    zfs))

(def ∈ (el zfs)
  (~is zfs!indices.el nil))
(def set-member? (el zfs)
  (∈ el zfs))

(def ⊂ (zf1 zf2)
  (let ret t
    (each (y x) zf1!values
      (aif (is zf2!indices.x nil) (= ret (no it))))
     ret))
(def subset-of? (zf1 zf2)
  (⊂ zf1 zf2))

(def set->table (zfs)
  (if zfs zfs!values (table)))

;(def set->list (zfs)
;  ())
; multitable
(def multitable ()
  (obj tag->values (table) value->tags (table) tags (table) values (table)))
(def +tag (mt tag val)
  (do
      (if (is mt nil)
        (= mt (multitable)))
      (zap insert mt!tags.tag t)
      (zap insert mt!values.val t)
      (zap insert mt!tag->values.tag val)
      (zap insert mt!value->tags.val tag)
      mt))

(def -tag (mt tag val)
  (do (zap remove mt!tag->values.tag val)
      (zap remove mt!value->tags.val val)
      mt))

(def tags->values (mt . tags)
  (do
    (with (container (set->table (mt!tag->values car.tags)) acc (zf) tagset (zfilll tags))
      (do
        (each (y x) container
          (do (if (⊂ tagset (mt!value->tags x))
                (zap insert acc x))))
        acc))))

; user schema
; login matches up with login
; name = real name
; characters = table of character sheets
; current-character = index of current character
(= users* (table))
(def new-user (lname)
  (do
    (= users*.lname (inst 'user 'login lname))
    (if (is nil actionqueues*.lname) (= actionqueues*.lname (multitable)))))
(= actionqueues* (table))

; Hack for the moment
(new-user "foo")

(mac setwpath (ob path (o ma 0))
  (with (it ob spl ((ac-scheme regexp-split) "/" (string path)))
    ;(zap map spl [string _])
    (zap coerce (car (nthcdr (- (len spl) 1) spl)) 'int)
    (each x spl (= it (list it (if (is (type x) 'int) (max ma x) (list 'quote (coerce x 'string))))))
    `(= ,@it)))

(mac getwpath (ob path)
  (with (it ob spl (rev:cdr:rev ((ac-scheme regexp-split) "/" (string path))))
    (each x spl (= it (list it (list 'quote (coerce (string x) 'string)))))
    it))

; each action queue is a multitable of type/data pairs, with type, date, and location tags
(mac addactionf (usr ty da loc)
  ``(addaction ,,usr ,,ty ,,da ,,loc))
(mac addaction (usr ty da loc)
  ``(do
      (+tag (actionqueues* ,,usr) ,,ty  (list "type" ,,ty "data" ,,da))
      (+tag (actionqueues* ,,usr) ,,loc (list "type" ,,ty "data" ,,da))
      (if (is ,,ty "XP Spend")
        (setwpath (charsheetsorange* ,,usr) ,,da ,(getwpath (charsheetsorange* ,usr) ,da)))
  ))
;        ``(setwpath (charsheetsorange* "foo") "attributes/Strength/3" ,(getwpath (charsheetsorange* "foo") "attributes/Strength/3"))

(defpathjson /addaction (req)
  (if (~is get-user.req nil)
    (do
      (eval (addactionf (get-user req) (arg req "ty") (arg req "da") (arg req "loc")))
      (prn "{res: true}"))
     (prn "{res: false}")))
(def removeaction (usr ty da loc)
  (do
      (-tag actionqueues*.usr ty  (list "type" ty "data" da))
      (-tag actionqueues*.usr loc (list "type" ty "data" da))
  ))

(defpathjson /removeaction (req)
  (if (~is get-user.req nil)
    (do
      (removeaction (get-user req) (arg req "ty") (arg req "da") (arg req "loc"))
      (prn "{res: true}"))
     (prn "{res: false}")))


(defpathjson /showactions (req)
  (tojson (obj futureactions (aif (actionqueues* get-user.req) it 'nothing) pastactions (aif (actionsdone* get-user.req) it 'nothing))))

(defpathjson /submitactions (req)
  (do
    (parse-actions get-user.req (arg req "aq"))
    (tojson (obj message 'success futureactions (aif (actionqueue* get-user.req) it 'nothing) pastactions (aif (actionsdone* get-user.req) it 'nothing)))))

(defpathjson /submitcharsheet (req)
  (do 
    (= (charsheets* (get-user req)) (fromjson (arg req "cs")))
    (save-table charsheets* "secret/charsheets")))

(= waitinglist* (table))
(mac w/touching (id . body)
  `(do1
     (do
       ,@body
     )
     (aif (waitinglist* id)
       (each x it
         (wake x)))))

; format [...,{ty: name, da: data}, ...]
(def parse-actions (usr json-data)
  ;assume this has been sanitized for the moment
  (w/touching usr
    (= (actionqueue* usr) '())
    (let parsed-data (fromjson json-data)
      (let end (- (len parsed-data) 1)
      (if (>= end 0)
        (for x 0 end
          (addactionf usr (parsed-data.x "ty") (parsed-data.x "da") (parsed-data.x "loc"))))))
  ))

(def make-reader ()
  ())

(def make-writer ()
  ())

(mac defc ()
  ())

;(= charsheets* (multitable))
; each charsheet should have an associated schema, and then be k,v pairs
; keys must be strings, values may be number, list or table
(def render-charsheet (charsheet) 
  ((charsheet "schema") charsheet))

(mac ret (name . body)
  `(let ,name nil
     ,@body
     ,name))

;(mac columns body
;  `(tag (div) ,@(ret foo (each x body (= foo (join foo (list (list 'tag '(div class "column") x))))))))

;(mac columns body
;  `(join (list 'tag '(div)) (mappend [list (list 'tag '(div) _)] ',body)))

(mac columns body
  ``(tag (div class "columns") ,@(mappend [mappend [list (list 'tag '(div class "column") _)] (eval _)] ',body) (prn)))


(mac w/lets (var expr . body)
  `(join '(let) '(,var) '(,expr)
     ',body))
(def columns2 (s) (eval (join '(columns) s)))

; page &body
; gold-body :title title-element :body &body
; columns &body
; dots number max

(= attributeblock* '(("Intelligence" "Wits" "Resolve") ("Strength" "Dexterity" "Stamina") ("Presence" "Manipulation" "Composure")))
(= skillblock* '(("Mental" ("Academics" "Computer" "Crafts" "Investigation" "Medicine" "Occult" "Politics" "Science")) ("Physical" ("Athletics" "Brawl" "Drive" "Firearms" "Larceny" "Stealth" "Survival" "Weaponry")) ("Social" ("Animal Ken" "Empathy" "Expression" "Intimidation" "Persuasion" "Socialize" "Streetwise" "Subterfuge"))))
(= skillobj* (obj "Mental" '("Academics" "Computer" "Crafts" "Investigation" "Medicine" "Occult" "Politics" "Science") "Physical" '("Athletics" "Brawl" "Drive" "Firearms" "Larceny" "Stealth" "Survival" "Weaponry") "Social" '("Animal Ken" "Empathy" "Expression" "Intimidation" "Persuasion" "Socialize" "Streetwise" "Subterfuge")))
(= arcana* '("Death" "Fate" "Forces" "Life" "Mind" "Matter" "Prime" "Space" "Spirit" "Time"))

; schema for charsheets
; attributes, skills
; faction - a symbol, one of pentacle, nephandi, seers, banishers, none, or meta
; merits are a list of tables (templ merit name dots specialisations submerits)

(deftem charsheet 
  "attributes" (obj "Intelligence" 1 "Wits" 1 "Resolve" 1 "Strength" 1 "Dexterity" 1 "Stamina" 1 "Presence" 1 "Manipulation" 1 "Composure" 1)
  "skills" (obj "Academics" 0 "Computer" 0 "Crafts" 0 "Investigation" 0 "Medicine" 0 "Occult" 0 "Politics" 0 "Science" 0 
              "Athletics" 0 "Brawl" 0 "Drive" 0 "Firearms" 0 "Larceny" 0 "Stealth" 0 "Survival" 0 "Weaponry" 0
              "Animal Ken" 0 "Empathy" 0 "Expression" 0 "Intimidation" 0 "Persuasion" 0 "Socialize" 0 "Streetwise" 0 "Subterfuge" 0)
  "gnosis" 1
  "arcana" (obj "Death" 0 "Fate" 0 "Forces" 0 "Life" 0 "Mind" 0 "Matter" 0 "Prime" 0 "Space" 0 "Spirit" 0 "Time" 0)
  "merits" (table)
  "faction" "pentacle" "wisdom" 7
  "name" "" "virtue" "" "vice" "" "cabal" "" "legacy" nil "order" "" "path" "")

(def locap-string (body)
 (tag (span class "locap") (pr body)))

(mac norm-string body
  `(tag (span class "norm") (pr (string ',body))))

(def dots (name value out-of (o editable t) (o func "cd_action"))
  (zap coerce value 'int)
  (tag (span class "right-align") (for x 1 value (eval (join (if editable `(tag (a href (string "javascript:" ',func "('" ',name "', " ',x ");"))) '(eval)) `((tag (img id (string ,name "/" ,x) src "s/b.png")))))) (for x (+ value 1) out-of (eval (join  (if editable `(tag (a href (string "javascript:" ',func "('" ',name "', " ',x ");"))) '(eval)) `((tag (img id (string ,name "/" ,x) src "s/w.png")))) ))))

;(mac mac/k (name lst . body)) 
;(mac/k () )
(def spring () (tag (span class "stretch")))
(mac centered body `(tag (div class "centered") ,@body))
(mac right-align body `(tag (span class "right-align") ,@body))

(mac gold-box args
  (with (flag 'test title nil body nil)
    (each x args
      (case flag
        test    (case x
                  :title (= flag ':title)
                  @title (= flag '@title)
                  :body  (= flag ':body)
                  @body  (= flag '@body))
        :title  (do (= flag 'test) (push x title))
        @title  (do (= flag 'test) (zap join title x))
        :body   (do (= flag 'test) (push x body))
        @body   (do (= flag 'test) (zap join body x))))
    `(tag (div class "gold-box")
      (tag (span) ,@title)
      (tag (br))
      (tag (div) ,@body))))

(mac tfip (label value id)
  `(+ (tag (label for id) (pr label)) (tag (input type "text" value value) (tag (button)))))
(def intext (id val)
  (let nid (escid id) (tag (span)
    (tag (div id (string (escidm id) 1)  onclick (string "javascript: $('#" nid "1').hide('slow'); $('#" nid "2').show('slow');")) (pr val))
    (tag (input id (string (escidm id) 2) class "hid cfi wri" value val))
  )))

(mac prlr (left right (o editable nil))
  `(+ (tag (div class "wri cft") (pr ,left)) (tag (span class "right-align") (if (is ,editable "cd_direct") (intext ,left ,right) (pr ,right))) (tag (div class "sep"))))

(def mage-charsheet (charsheet (o editable "cd_direct"))
  (tag (section class "character-sheet")
    (tag (div class "columns") 
      (tag (div class "column") (tag (span) (prlr "Player name: " (charsheet "player") editable)) (br) (tag (span) (prlr "Character name: " (charsheet "name") editable)) (br) (tag (span) (prlr "Cabal: " (charsheet "cabal") editable)))
      (tag (div class "column") (tag (span) (prlr "Virtue: " (charsheet "virtue") editable)) (br) (tag (span) (prlr "Vice: " (charsheet "vice") editable)))
      (tag (div class "column") (tag (span) (prlr "Order: " (charsheet "order") editable)) (br) (tag (span) (prlr "Path: " (charsheet "path") editable)) (br) (if (~is (charsheet "legacy") nil) (tag (span) (prlr "Legacy: " (charsheet "legacy") editable)))))
    (gold-box :body (columns ))
    (gold-box :title (centered:locap-string "Attributes")
      :body (tag (div class "columns") (each x attributeblock* (tag (div class "column")
              (each y x (+ (tag (span class "wri") (pr y)) (dots (string "attributes/" y) ((charsheet "attributes") y) 5 t editable) (tag (div class "sep"))))))))
    (gold-box :title (centered:locap-string "Skills")
      :body (tag (div class "columns") (each x '("Mental" "Physical" "Social") (tag (div class "column") (+ (locap-string x) (tag (div class "sep")) (each y skillobj*.x (+ (tag (span class "wri") (pr y)) (dots (string "skills/" y) ((charsheet "skills") y) 5 t editable) (tag (div class "sep")))))))))
    (gold-box @title ((locap-string "Merits") (right-align:locap-string "Arcana"))
      @body 
      ((tag (div class "column") (each (merit numd) (charsheet "merits") (tag (span) (tag (span class "wri") (pr merit)) (dots (string "merits/" merit) numd 5 t editable))))
       (tag (div class "right-align") (each x arcana* (+ (tag (span class "wri") (pr x)) (dots (string "arcana/" x) ((charsheet "arcana") x) 5 t editable) (tag (div class "sep"))))
         (centered:norm-string "Gnosis") (tag (br)) (dots "gnosis" (charsheet "gnosis") 10 nil editable)
         (centered:norm-string "Willpower") (tag (br)) (dots "willpower" (+ ((charsheet "attributes") "Composure") ((charsheet "attributes") "Resolve")) 10 nil editable)
         (centered:norm-string "Wisdom") (tag (br)) (dots "wisdom" (charsheet "wisdom") 10 nil editable)
 )))))

(defpathjson /csjson (req)
  (tojson (obj charsheet (charsheets* get-user.req) orange (charsheetsorange* get-user.req))))
(defpathl /cs (req)
  (if (admin get-user.req)
    (page "Ascension Auckland: Character sheets" "s/style.css" ("s/jquery-1.4.2.min.js" "s/standard.js")
      (+ (tag header (tag h1 (pr "Nexus"))) (header) (tag (section class "charsheet") (each (k v) tablist.hpasswords* (tag span (pr k " ")
               (if (charsheets* k)
                 (+ (tag (a href (+ "cs?view=" k))  (pr "View character sheet")))
                 (+ (tag (a href (+ "cs?create=" k))(pr "Create blank character sheet") )) )) (tag br)) )))
    (page "Ascension Auckland: Character sheet" "s/style.css" ("s/jquery-1.4.2.min.js" "s/standard.js") 
      (let cs (charsheets* get-user.req) 
        (+ (tag header (tag h1 (pr "Nexus"))) (header) (tag (section class "charsheet") (tag (script type "application/javascript") (prn "\ninitialise_charsheet();")) (mage-charsheet cs)))))))


(clear-cache-directories)
(load-userinfo)

(defpath-raw /sessions (req)
  (logout-user (get-user req))
  (aif (good-login (arg req "u") (arg req "p") req!ip)
       (do (= (logins* it) req!ip)
           (redirect (aif (arg req "goto") it "/index.html") http-found+ (copy httpd-hds* 'Set-Cookie (+ "user=" (user->cookie* it) "; expires=Sun, 17-Jan-2038 19:14:07 GMT"))))
       (redirect "/index.html")))

(mac actions ()
  `(tag (div class "containerthing")
     (tag (div class "messagepane"))
     (tag (div class "actions")
       (tag (div class "deadactions"))
       (tag (div class "liveactions"))
   )))

(defop longpoll req
  ())

(defpath /aq req
  (page "Ascension Auckland: Action Queue" "s/style.css" ("s/jquery-1.4.2.min.js" "s/jquery-ui-1.8.1.custom.min.js" "s/standard.js")
    (tag (div)
         (tag (script type "application/javascript") (pr "
<![CDATA[
$(document)).ready(function(){
  actionise();
  get_action_queue_from_server();
});
]]>
"))
         (header)
         (actions))))

; redefine login page for the moment; deal with this in a more ajaxy way in future
(def login-page (switch (o msg nil) (o afterward nil))
  (page "Log in" "s/style.css" ("s/jquery-1.4.2.min.js" "s/standard.js") (tag (div) 
   (pagemessage msg)
   (tag (fieldset id "signing_menu" class "more-common-form")
     (tag (form method "post" id "signin" action "/sessions")
       (tag (p) (tag (label for "u")(pr "Username"))
       (tag (input type "text" id "u" name "u" value "" title "u")))       
       (tag (p) (tag (label for "p")(pr "Password"))
       (tag (input type "password" id "p" name "p" value "" title "p")))
       (tag (p class "remember") (tag (input type "submit" id "signin-submit" value "Sign in"))
       (tag (input type "checkbox" id "remember" name "remember_me" value "1"))
       (aif (cadr afterward) (tag (input id "goto" name "goto" type "hidden" value it)))
       (tag (label for "remember") (pr "Remember me")))
     )
   ))))
(load-userinfo)
(= httpd-handler dispatch)
(start-httpd 8020)
