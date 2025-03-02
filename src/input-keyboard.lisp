(in-package #:virality.input)

(a:define-constant +key-names+
    #(:unknown nil nil nil :a :b :c :d :e :f :g :h :i :j :k :l :m :n :o :p :q :r
      :s :t :u :v :w :x :y :z :1 :2 :3 :4 :5 :6 :7 :8 :9 :0 :return :escape
      :backspace :tab :space :minus :equals :leftbracket :rightbracket
      :backslash :nonushash :semicolon :apostrophe :grave :comma :period :slash
      :capslock :f1 :f2 :f3 :f4 :f5 :f6 :f7 :f8 :f9 :f10 :f11 :f12 :printscreen
      :scrolllock :pause :insert :home :pageup :delete :end :pagedown :right
      :left :down :up :numlockclear :kp_divide :kp_multiply :kp_minus :kp_plus
      :kp_enter :kp_1 :kp_2 :kp_3 :kp_4 :kp_5 :kp_6 :kp_7 :kp_8 :kp_9 :kp_0
      :kp_period :nonusbackslash :application :power :kp_equals :f13 :f14 :f15
      :f16 :f17 :f18 :f19 :f20 :f21 :f22 :f23 :f24 :execute :help :menu :select
      :stop :again :undo :cut :copy :paste :find :mute :volumeup :volumedown
      :lockingcapslock :lockingnumlock :lockingscrolllock :kp_comma
      :kp_equalsas400 :international1 :international2 :international3
      :international4 :international5 :international6 :international7
      :international8 :international9 :lang1 :lang2 :lang3 :lang4 :lang5 :lang6
      :lang7 :lang8 :lang9 :alterase :sysreq :cancel :clear :prior :return2
      :separator :out :oper :clearagain :crsel :exsel nil nil nil nil nil nil
      nil nil nil nil nil :kp_00 :kp_000 :thousandsseparator :decimalseparator
      :currencyunit :currencysubunit :kp_leftparen :kp_rightparen :kp_leftbrace
      :kp_rightbrace :kp_tab :kp_backspace :kp_a :kp_b :kp_c :kp_d :kp_e :kp_f
      :kp_xor :kp_power :kp_percent :kp_less :kp_greater :kp_ampersand
      :kp_dblampersand :kp_verticalbar :kp_dblverticalbar :kp_colon :kp_hash
      :kp_space :kp_at :kp_exclam :kp_memstore :kp_memrecall :kp_memclear
      :kp_memadd :kp_memsubtract :kp_memmultiply :kp_memdivide :kp_plusminus
      :kp_clear :kp_clearentry :kp_binary :kp_octal :kp_decimal :kp_hexadecimal
      nil nil :lctrl :lshift :lalt :lgui :rctrl :rshift :ralt :rgui nil nil nil
      nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil nil
      nil nil nil nil :mode :audionext :audioprev :audiostop :audioplay
      :audiomute :mediaselect :www :mail :calculator :computer :ac_search
      :ac_home :ac_back :ac_forward :ac_stop :ac_refresh :ac_bookmarks
      :brightnessdown :brightnessup :displayswitch :kbdillumtoggle :kbdillumdown
      :kbdillumup :eject :sleep)
  :test #'equalp)

;;; Events

(defun on-key-up (context key)
  (let ((data (v::input-data (v::core context))))
    (input-transition-out data (list :key key))
    (input-transition-out data '(:key :any))
    (input-transition-out data '(:button :any))))

(defun on-key-down (context key)
  (let ((data (v::input-data (v::core context))))
    (input-transition-in data (list :key key))
    (input-transition-in data '(:key :any))
    (input-transition-in data '(:button :any))))
