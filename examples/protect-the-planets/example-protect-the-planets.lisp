(in-package #:virality.examples.protect-the-planets)

;; To run this game, start your lisp repl, then:
;;
;; (ql:quickload :virality.examples)
;; (virality.engine:start :scene 'virality.examples.ptp:ptp)

;; "Protect the Planets!"
;; by Peter Keller (psilord@cs.wisc.edu)
;; With significant contributions by: Michael Fiano (mail@michaelfiano.com)
;;
;; Requirements: gamepad, preferably xbox/ps4 like, linux, gtx 660 or better but
;; nvidia gpus are not specifically required.
;;
;; Controls:
;; left stick controls movement,
;; right-stick controls shooting and direction of shooting,
;; right trigger slows movement.

;; The commented delimited categories group the code into various sections.  The
;; FL related sections, like Textures, Materials, Components, etc, generally
;; don't have to be in this order and don't have to be in a single file. They
;; can be spread sround and in any order you like. BUT--Components must be
;; defined before the Prefabs that use it.


;; TODO: Pixel_Outlaw says to use an egg shape for a shot pattern:
;; http://i.imgur.com/J6oKb1E.png
;; And here is some math that can help:
;; http://www.mathematische-basteleien.de/eggcurves.htm

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; NOTE: Because we don't yet have mesh/sprite rendering order in Virality
;; Engine, or order independent transparency tools, etc yet, we'll need to
;; define were things exist in layers perpendicular to the orthographic camera
;; so they can be rendered in order according to the zbuffer. This also means no
;; translucency since the rendering can happen in any order. Stencil textures
;; are ok though. NOTE: We must be careful here since things that collide with
;; each other must actually be physically close together in the game.
(defparameter *draw-layer* (u:dict :starfield -100f0
                                   :player-stable -99f0

                                   :planet -.08f0
                                   :planet-warning-explosion -.07f0
                                   :planet-explosion -.06f0
                                   :asteroid -.05f0
                                   :enemy-ship -.04f0
                                   :enemy-explosion -.03f0
                                   :enemy-bullet -.02f0
                                   :player-bullet -.01f0
                                   :player 0.00f0
                                   :player-explosion 0.01f0

                                   :time-keeper 300f0
                                   :sign 400f0
                                   :camera 500f0
                                   ))
(defun dl (draw-layer-name)
  (u:href *draw-layer* draw-layer-name))


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Shaders
;;
;; Herein we define special shaders this game needs.
;;
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; WARNING!!!!
;;
;; Shaders MUST currently be written in another package, so we change packages
;; here to author the shaders, then we change back to the example package for
;; all code after it. In addition, shaders, when defined in this kind of
;; context, must be defined in an EVAL-ALWAYS form since the export embedded in
;; the define-shader form must happen at macro expansion time to other things
;; later like the define-material can see it.
;;
;; Normally, you'd put this into a different file and there the EVAL-ALWAYS is
;; unnecessary (but it must be loaded before anything that uses that shader
;; symbol name). However, I wanted the ENTIRE codebase to be in one file to
;; demonstrate this is possible for a game.

(in-package #:virality.examples.shaders)

(define-function starfield/frag ((color :vec4)
                                 (uv1 :vec2)
                                 &uniform
                                 (tex :sampler-2d)
                                 (time :float)
                                 (mix-color :vec4))
  (let ((tex-color (texture tex (vec2 (.x uv1) (- (.y uv1) (/ time 50.0))))))
    (* tex-color mix-color)))


(define-shader starfield ()
  (:vertex (shd/tex:unlit/vert mesh-attrs))
  (:fragment (starfield/frag :vec4 :vec2)))


;; Back to our regularly scheduled package!
(in-package #:virality.examples.protect-the-planets)

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Textures
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; We only use a single sprite sheet atlas that contains all of our textures.
;; This one is invluded with FL
(v:define-texture sprite-atlas (:texture-2d)
  (:data #(:spritesheet)))

;; This background image was downloaded off the web here:
;; https://www.wikitree.com/photo/jpg/Tileable_Background_Images
;; And the url for the license is 404, but the wayback machine found it:
;; https://web.archive.org/web/20180723233810/http://webtreats.mysitemyway.com/terms-of-use/
;; Which says it can be used for any purpose.
(v:define-texture starfield (:texture-2d)
  (:data #((:texture "starfield.tiff"))))

;; These two textures were created by Pixel_Outlaw for use in this game.
(v:define-texture warning-wave (:texture-2d)
  (:data #((:texture "warning-wave.tiff"))))

(v:define-texture warning-mothership (:texture-2d)
  (:data #((:texture "warning-mothership.tiff"))))

(v:define-texture game-over (:texture-2d)
  (:data #((:texture "game-over.tiff"))))

(v:define-texture title (:texture-2d)
  (:data #((:texture "title.tiff"))))

(v:define-texture level-complete (:texture-2d)
  (:data #((:texture "level-complete.tiff"))))

(v:define-texture white (:texture-2d x/tex:clamp-all-edges)
  (:data #((:texture "white.tiff"))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Materials
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; A material is pre-packaged set of values for a particular shader. Different
;; materials can be made for the same shader each providing diferent inputs to
;; that shader.
(v:define-material sprite-sheet
  (:profiles (x/mat:u-mvp)
   :shader shd/sprite:sprite
   :uniforms ((:sprite.sampler 'sprite-atlas) ;; refer to the above texture.
              (:opacity 1.0)
              (:alpha-cutoff 0.1))
   :blocks ((:block-name :spritesheet
             :storage-type :buffer
             :block-alias :spritesheet
             :binding-policy :manual))))

(v:define-material title
  (:profiles (x/mat:u-mvp)
   :shader shd/tex:unlit-texture-decal
   :uniforms ((:tex.sampler1 'title)
              (:min-intensity (v4:vec 0f0 0f0 0f0 .5f0))
              (:max-intensity (v4:one)))))

(v:define-material starfield
  (:profiles (x/mat:u-mvpt)
   :shader ex/shd:starfield
   :uniforms ((:tex 'starfield)
              (:mix-color (v4:one)))))

(v:define-material warning-mothership
  (:profiles (x/mat:u-mvp)
   :shader shd/tex:unlit-texture-decal
   :uniforms ((:tex.sampler1 'warning-mothership)
              (:min-intensity (v4:vec 0f0 0f0 0f0 .5f0))
              (:max-intensity (v4:one)))))

(v:define-material warning-wave
  (:profiles (x/mat:u-mvp)
   :shader shd/tex:unlit-texture-decal
   :uniforms ((:tex.sampler1 'warning-wave)
              (:min-intensity (v4:vec 0f0 0f0 0f0 .5f0))
              (:max-intensity (v4:one)))))

(v:define-material game-over
  (:profiles (x/mat:u-mvp)
   :shader shd/tex:unlit-texture-decal
   :uniforms ((:tex.sampler1 'game-over)
              (:min-intensity (v4:vec 0f0 0f0 0f0 .5f0))
              (:max-intensity (v4:one)))))

(v:define-material level-complete
  (:profiles (x/mat:u-mvp)
   :shader shd/tex:unlit-texture-decal
   :uniforms ((:tex.sampler1 'level-complete)
              (:min-intensity (v4:vec 0f0 0f0 0f0 .5f0))
              (:max-intensity (v4:one)))))

(v:define-material time-bar
  (:profiles (x/mat:u-mvp)
   :shader shd/tex:unlit-texture
   :uniforms ((:tex.sampler1 'white)
              (:mix-color (v4:vec 0 1 0 1)))))


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Random Types we need, some will go into FL properly in a future date.
;; TODO: Especially these can be used to represent collision volumes and I
;; should propogate the changes into the right places.
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass region ()
  ((%center :accessor center
            :initarg :center
            :initform (v3:zero))))

(defclass region-cuboid (region)
  ((%minx :accessor minx
          :initarg :minx)
   (%maxx :accessor maxx
          :initarg :maxx)
   (%miny :accessor miny
          :initarg :miny)
   (%maxy :accessor maxy
          :initarg :maxy)
   (%minz :accessor minz
          :initarg :minz)
   (%maxz :accessor maxz
          :initarg :maxz)))

(defun make-region-cuboid (center minx maxx miny maxy minz maxz)
  (make-instance 'region-cuboid
                 :center center
                 :minx (float minx 1f0)
                 :maxx (float maxx 1f0)
                 :miny (float miny 1f0)
                 :maxy (float maxy 1f0)
                 :minz (float minz 1f0)
                 :maxz (float maxz 1f0)))

(defclass region-sphere (region)
  ;; A specific type to make math faster when it is KNOWN one is using a sphere
  ;; for something.
  ((%radius :accessor radius
            :initarg :radius)))

(defun make-region-sphere (center radius)
  (make-instance 'region-sphere :center center :radius radius))

(defclass region-ellipsoid (region)
  ;; positive distances of each principal axis.
  ;; Can be used to make 2d or 3d circles, ellipses, spheres, spheroids, etc.
  ((%x :accessor x
       :initarg :x)
   (%y :accessor y
       :initarg :y)
   (%z :accessor z
       :initarg :z)))

(defun make-region-ellipsoid (center x y z)
  (make-instance 'region-ellipsoid :center center
                                   :x (float x 1f0)
                                   :y (float y 1f0)
                                   :z (float z 1f0)))


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Utility functions some will go into FL in a future date.
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun clip-movement-vector (movement-vector current-translation region-cuboid)
  "Clip the MOVEMENT-VECTOR by an amount that will cause it to not violate the
REGION-CUBOID when MOVEMENT-VECTOR is added to the CURRENT-TRANSLATION.
Return a newly allocated and adjusted MOVEMENT-VECTOR."

  (with-accessors ((center center)
                   (minx minx) (maxx maxx) (miny miny) (maxy maxy)
                   (minz minz) (maxz maxz))
      region-cuboid
    (v3:with-components ((c current-translation)
                         (m movement-vector))
      ;; add the movement-vector to the current-translation
      (let* ((nx (+ cx mx))
             (ny (+ cy my))
             (nz (+ cz mz))
             ;; And the default adjustments to the movement-vector
             (adj-x 0)
             (adj-y 0)
             (adj-z 0))
        ;; Then if it violates the boundary cube, compute the adjustment we
        ;; need to the movement vector to fix it.
        (let ((offset-minx (+ (v3:x center) minx))
              (offset-maxx (+ (v3:x center) maxx))
              (offset-miny (+ (v3:y center) miny))
              (offset-maxy (+ (v3:y center) maxy))
              (offset-minz (+ (v3:z center) minz))
              (offset-maxz (+ (v3:z center) maxz)))
          (when (< nx offset-minx)
            (setf adj-x (- offset-minx nx)))

          (when (> nx offset-maxx)
            (setf adj-x (- offset-maxx nx)))

          (when (< ny offset-miny)
            (setf adj-y (- offset-miny ny)))

          (when (> ny offset-maxy)
            (setf adj-y (- offset-maxy ny)))

          (when (< nz offset-minz)
            (setf adj-z (- offset-minz nz)))

          (when (> nz offset-maxz)
            (setf adj-z (- offset-maxz nz)))

          ;; NOTE: Allocates memory.
          (v3:vec (+ mx adj-x) (+ my adj-y) (+ mz adj-z)))))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Components
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ;;;;;;;;;
;; Component: player-movement
;;
;; First we need a component that allows the player to move around.
;; We're going to left the left joystick place the player and the right one
;; orient the player.
;; ;;;;;;;;;

(v:define-component player-movement ()
  ((%transform :accessor transform
               :initarg :transform
               :initform nil)
   (%max-velocity :accessor max-velocity
                  :initarg :max-velocity
                  :initform 1500)
   (%translate-deadzone :accessor translate-deadzone
                        :initarg :translate-deadzone
                        :initform .1)
   (%rotate-deadzone :accessor rotate-deadzone
                     :initarg :rotate-deadzone
                     :initform .1)
   ;; We just hack in a boundary cube you can't go outside of. This is in the
   ;; local space of the actor to which this component is attached.
   ;; The format is minx, maxx, miny, maxy, minz, maxz
   (%region-cuboid :accessor region-cuboid
                   :initarg :region-cuboid
                   :initform (make-region-cuboid (v3:vec 0.0 0.0 0.0)
                                                 -900 900 -500 500 0 0))))

;; upon attaching, this component will store find the transform component
;; on the actor to which it has been attached and keep a direct reference to it.
(defmethod v:on-component-attach ((self player-movement) actor)
  (declare (ignore actor))
  (with-accessors ((actor v:actor) (transform transform)) self
    (setf transform (v:component-by-type actor 'c/xform:transform))))


(defmethod v:on-component-update ((self player-movement))
  (with-accessors ((context v:context) (transform transform)
                   (max-velocity max-velocity)
                   (translate-deadzone translate-deadzone)
                   (rotate-deadzone rotate-deadzone)
                   (region-cuboid region-cuboid))
      self
    (u:mvlet ((lx ly (v:get-gamepad-analog context '(:gamepad1 :left-stick)))
              (instant-p (zerop (v:frame-count context))))

      ;; First, we settle the notion of how the player translates around with
      ;; left stick
      (u:mvlet*
          (;; Deal with deadzones and other bad data around the input vector.
           (vec (v3:vec lx ly 0))
           (vec (if (> (v3:length vec) 1) (v3:normalize vec) vec))
           (vec (if (< (v3:length vec) translate-deadzone) (v3:zero) vec))
           ;; Right trigger modifies speed. pull to lerp from full speed
           ;; to half speed.
           (ty
            (nth-value 1 (v:get-gamepad-analog
                          context '(:gamepad1 :triggers))))
           ;; Compute the actual translation vector related to our frame time!
           (vec
            (v3:scale vec
                      (float (* (a:lerp ty max-velocity (/ max-velocity 2f0))
                                (v:frame-time context))
                             1f0)))
           ;; and ensure we clip the translation vector so we can't go out of
           ;; the boundary cube we set.
           (current-translation
            ;; TODO NOTE: Prolly should fix these to be external.
            (c/xform::current (c/xform::translation transform)))
           (vec (clip-movement-vector vec current-translation region-cuboid)))

        (c/xform:translate transform vec))

      ;; Then we settle the notion of how the player is oriented.  We're setting
      ;; a hard angle of rotation each time so we overwrite the previous value.
      (unless (or (= lx ly 0.0) (< (v3:length (v3:vec lx ly 0)) rotate-deadzone))
        (let* ((angle (atan (- lx) ly))
               (angle (if (< angle 0)
                          (+ pi (- pi (abs angle)))
                          angle)))
          (c/xform:rotate transform
                          (q:orient :local :z angle)
                          :replace-p t
                          :instant-p instant-p))))))

;; ;;;;;;;;;
;; Component: line-mover
;;
;; Move something in a straight line along a specified cardinal axis. This is
;; not a sophisticated component. We use it to move projectiles.
;;;;;;;;;

(v:define-component line-mover ()
  ((%direction :accessor direction
               :initarg :direction
               ;; NOTE: may be :+y :-y :+x :-x :+z :-z or a vec3
               :initform :+y)
   (%transform :accessor transform
               :initarg :transform
               :initform nil)
   (%velocity :accessor velocity
              :initarg :velocity
              :initform 0)))

(defmethod v:on-component-attach ((self line-mover) actor)
  (declare (ignore actor))
  (with-accessors ((actor v:actor) (transform transform)) self
    (setf transform (v:component-by-type actor 'c/xform:transform))))

(defmethod v:on-component-physics-update ((self line-mover))
  (with-accessors ((context v:context)
                   (transform transform)
                   (velocity velocity)
                   (direction direction))
      self
    ;; TODO: Figure out why I need this when physics is faster. It appears I
    ;; can compute a physics frame before components are attached?
    (when transform
      (c/xform:translate
       transform
       (let* ((local (c/xform:local transform))
              (x (m4:rotation-axis-to-vec3 local :x))
              (y (m4:rotation-axis-to-vec3 local :y))
              (z (m4:rotation-axis-to-vec3 local :z))
              (a (v3:normalize
                  (if (symbolp direction)
                      (ecase direction
                        (:+x x)
                        (:-x (v3:negate x))
                        (:+y y)
                        (:-y (v3:negate y))
                        (:+z z)
                        (:-z (v3:negate z)))
                      direction)))
              (move-delta (* velocity (v:delta context))))
         (v3:scale a move-delta))))))

;; ;;;;;;;;;
;; Component: damage-points
;;
;; We describe an amount of damage that we give to something under appropriate
;; conditions during a collision. No need for any methods since this is only a
;; repository of information consulted by the game as it is needed for each
;; appropriate actor that has it.
;; ;;;;;;;;;

(v:define-component damage-points ()
  ((%dp :accessor dp
        :initarg :dp
        :initform 1)))

;; ;;;;;;;;;
;; Component: hit-points
;;
;; Manage a number of hit-points for something and destroy my actor if I fall
;; to zero or below.
;;;;;;;;;

(v:define-component hit-points ()
  ((%hp :accessor hp
        :initarg :hp
        :initform 1)
   (%invulnerability-timer :accessor invulnerability-timer
                           :initarg :invulnerability-timer
                           :initform 0)
   ;; Usually we want to auto manage our hit points by referencing this
   ;; component via a collider referent. In that case, we can allow
   ;; invulnerability and auto-destruction. Sometimes, in the case of a planet,
   ;; we want to manage the hit-points manually, and in those cases we turn
   ;; those features off.
   (%allow-invulnerability :accessor allow-invulnerability
                           :initarg :allow-invulnerability
                           :initform t)
   (%allow-auto-destroy :accessor allow-auto-destroy
                        :initarg :allow-auto-destroy
                        :initform t)))


(defmethod v:on-component-update ((self hit-points))
  (with-accessors ((context v:context)
                   (allow-invulnerability allow-invulnerability)
                   (invulnerability-timer invulnerability-timer))
      self

    (when (and allow-invulnerability (> invulnerability-timer 0))
      (decf invulnerability-timer (v:frame-time context))
      (when (<= invulnerability-timer 0)
        (setf invulnerability-timer 0)))))

(defmethod possibly-accept-damage ((self hit-points) other-collider)
  (with-accessors ((context v:context)
                   (allow-auto-destroy allow-auto-destroy)
                   (invulnerability-timer invulnerability-timer))
      self
    (let ((other-damage-points (v:component-by-type
                                (v:actor other-collider)
                                'damage-points)))

      (when (> invulnerability-timer 0)
        ;; If we're invulnerable, we cannot take damage.
        (return-from possibly-accept-damage nil))

      (cond
        (other-damage-points
         (decf (hp self) (dp other-damage-points)))
        (t
         ;; The physics system discovered a hit, but the thing that hit us
         ;; doesn't have a hit-points component, so we'll assume one point
         ;; of damage arbitrarily.
         (decf (hp self) 1)))

      (when (<= (hp self) 0)
        ;; Currently, we can only have 0 hitpoints as the min.
        (setf (hp self) 0)))))

(defmethod possibly-auto-destroy ((self hit-points))
  (with-accessors ((context v:context)
                   (allow-auto-destroy allow-auto-destroy)
                   (invulnerability-timer invulnerability-timer))
      self
    (when (and allow-auto-destroy (<= (hp self) 0))
      ;; Destroy my actor.
      (v:destroy (v:actor self))
      ;; And, if the actor had an explosion component, cause the explosion
      ;; to happen
      (possibly-make-explosion-at-actor (v:actor self)))))


(defmethod v:on-collision-enter ((self hit-points) other-collider)
  (with-accessors ((context v:context)
                   (allow-auto-destroy allow-auto-destroy)
                   (invulnerability-timer invulnerability-timer))
      self
    (possibly-accept-damage self other-collider)
    (possibly-auto-destroy self)))

;; ;;;;;;;;;
;; Component: projectile
;;
;; This describes a projectile (bullet, asteroid, etc) and its API to set it up
;; when it spawns.
;;;;;;;;;

(v:define-component projectile ()
  ((%name :accessor name
          :initarg :name
          :initform nil)
   (%frames :accessor frames
            :initarg :frames
            :initform 0)
   (%transform :accessor transform
               :initarg :transform
               :initform nil)
   (%collider :accessor collider
              :initarg :collider
              :initform nil)
   (%mover :accessor mover
           :initarg :mover
           :initform nil)
   (%sprite :accessor sprite
            :initarg :sprite
            :initform nil)
   (%action :accessor action
            :initarg :action
            :initform nil)))

;; we use this at runtime to instantiate a bullet prefab and fill in everything
;; it needs to become effective in the world.
(defun make-projectile (context translation rotation physics-layer depth-layer
                        &key
                          (parent nil)
                          (scale (v3:one))
                          (destroy-ttl 2)
                          (velocity 1000)
                          (direction :+y)
                          (prefab-name "projectile")
                          (prefab-library 'ptp)
                          (name "bullet01")
                          (frames 1))
  (let* ((new-projectile
           ;; TODO: This API needs to take a context. prefab-descriptor prolly
           ;; needs to be a function, not a macro.
           (first (v:make-prefab-instance
                   (v::core context)
                   ;; TODO: prefab-descriptor is wrong here.
                   `((,prefab-name ,prefab-library))
                   :parent parent)))
         ;; TODO: I'm expecting the new-projectile to have components here
         ;; without having gone through the flow. BAD!
         (projectile-transform (v:component-by-type new-projectile
                                                    'c/xform:transform))
         (projectile (v:component-by-type new-projectile 'projectile)))

    ;; Set the spatial configuration
    (setf (v3:z translation) (dl depth-layer))
    (c/xform:translate projectile-transform translation
                       :instant-p t :replace-p t)
    ;; XXX This interface needs to take a quat here also
    (c/xform:rotate projectile-transform rotation
                    :instant-p t :replace-p t)
    ;; And adjust the scale too.
    (c/xform:scale projectile-transform scale
                   :instant-p t :replace-p t)

    (setf
     ;; Basic identification of the projectile
     (name projectile) name
     (frames projectile) frames
     ;; Give the collider a cheesy name until I get rid of this name feature.
     (v:display-id (collider projectile)) name
     ;; Set what layer is the collider on?
     ;; TODO: When setting this, ensure I move the collider to the right
     ;; layer in the physics system.
     (c/col:on-layer (collider projectile)) physics-layer
     ;; How fast is the projectile going?
     (velocity (mover projectile)) velocity
     ;; Tell the sprite what it should be rendering
     ;; TODO: make NAME and FRAMES public for sprite component.
     (c/sprite:name (sprite projectile)) name
     (c/sprite:frames (sprite projectile)) frames

     ;; and, what direction is it going in?
     (direction (mover projectile)) direction)

    ;; By default projectiles live a certain amount of time.
    (v:destroy-after-time new-projectile :ttl destroy-ttl)

    new-projectile))


;; ;;;;;;;;;
;; Component: explosion
;;
;; Describe an explosion.
;;;;;;;;;

(v:define-component explosion ()
  ((%sprite :accessor sprite
            :initarg :sprite
            :initform nil)
   (%name :accessor name
          :initarg :name
          :initform "explode01-01")
   (%scale :accessor scale
           :initarg :scale
           :initform (v3:one))
   (%frames :accessor frames
            :initarg :frames
            :initform 15)))

;; NOTE: No physics layers for this since they don't even participate in the
;; collisions.
(defun make-explosion (context translation rotation scale
                       &key (destroy-ttl 2)
                         (prefab-name "generic-explosion")
                         (prefab-library 'ptp)
                         (name "explode01-01")
                         (frames 15))
  (let* ((new-explosion
           (first (v:make-prefab-instance
                   (v::core context)
                   ;; TODO: prefab-descriptor is wrong here.
                   `((,prefab-name ,prefab-library)))))
         (explosion-transform (v:component-by-type new-explosion
                                                   'c/xform:transform))
         (explosion (v:component-by-type new-explosion 'explosion)))

    (setf
     ;; Configure the sprite.
     (c/sprite:name (sprite explosion)) name
     (c/sprite:frames (sprite explosion)) frames)

    (c/xform:scale explosion-transform scale
                   :instant-p t :replace-p t)
    (c/xform:translate explosion-transform translation
                       :instant-p t :replace-p t)
    (c/xform:rotate explosion-transform rotation
                    :instant-p t :replace-p t)

    ;; By default explosions live a certain amount of time.
    (v:destroy-after-time new-explosion :ttl destroy-ttl)

    new-explosion))

(defun possibly-make-explosion-at-actor (actor)
  (let* ((context (v:context actor))
         (actor-transform (v:component-by-type actor 'c/xform:transform))
         (parent-model (c/xform:model actor-transform))
         (parent-translation (m4:get-translation parent-model))
         (parent-rotation (q:from-mat4 parent-model))
         (explosion (v:component-by-type actor 'explosion)))
    (when explosion
      (make-explosion context
                      parent-translation
                      parent-rotation
                      (scale explosion)
                      :name (name explosion)
                      :frames (frames explosion)))))

;; ;;;;;;;;;
;; Component: gun
;;
;; This fires the specified projectiles
;;;;;;;;;

(v:define-component gun ()
  ((%emitter-transform :accessor emitter-transform
                       :initarg :emitter-transform
                       :initform nil)
   (%physics-layer :accessor physics-layer
                   :initarg :physics-layer
                   :initform nil)
   (%depth-layer :accessor depth-layer
                 :initarg :depth-layer
                 :initform nil)
   (%rotate-deadzone :accessor rotate-deadzone
                     :initarg :rotate-deadzone
                     :initform .1)
   (%fire-period :accessor fire-period
                 :initarg :fire-period
                 :initform 25) ;; hz
   ;; Keeps track of how much time passed since we fired last.
   (%cooldown-time :accessor cooldown-time
                   :initarg :cooldown-time
                   :initform 0)
   ;; name and frames of projectile to fire.
   (%name :accessor name
          :initarg :name
          :initform "bullet01")
   (%frames :accessor frames
            :initarg :frames
            ;; TODO: Bug, if I put 1 here, I get the WRONG sprite sometimes.
            :initform 2)))

(defmethod v:on-component-attach ((self gun) actor)
  (declare (ignore actor))
  (with-accessors ((actor v:actor) (emitter-transform emitter-transform)) self
    (setf emitter-transform (v:component-by-type actor 'c/xform:transform))))

(defmethod v:on-component-update ((self gun))
  (with-accessors ((context v:context)
                   (rotate-deadzone rotate-deadzone)
                   (fire-period fire-period)
                   (cooldown-time cooldown-time)
                   (emitter-transform emitter-transform)
                   (depth-layer depth-layer))
      self

    ;; TODO: I could make a macro to do this syntax work, like WITH-TIMER, but I
    ;; think a names registrant of a function into the component that is called
    ;; repeatedly is better since enabling and disabling from elsewhere becomes
    ;; possible. Will think about for later.
    (cond
      ;; We exceeded our cooldown time, so time to fire!
      ((>= cooldown-time (/ fire-period))
       ;; We keep track of time such that we're most accurate in time that we
       ;; next need to fire.
       (loop :while (>= cooldown-time (/ fire-period))
             :do (decf cooldown-time (/ fire-period)))

       (u:mvlet ((rx ry (v:get-gamepad-analog context
                                              '(:gamepad1 :right-stick))))
         (let* ((parent-model (c/xform:model emitter-transform))
                (parent-translation (m4:get-translation parent-model)))
           (unless (or (= rx ry 0.0)
                       (< (v3:length (v3:vec rx ry 0)) rotate-deadzone))
             (let* ((angle (atan (- rx) ry))
                    (angle (if (< angle 0)
                               (+ pi (- pi (abs angle)))
                               angle)))
               ;; The rotation we use is indicated by the right stick vector.
               (make-projectile context
                                parent-translation
                                (q:orient :local :z angle)
                                (physics-layer self)
                                depth-layer
                                :velocity 2000
                                :name (name self)
                                :frames (frames self)))))))

      ;; Just accumulate more time until we know we can fire again.
      (t
       (incf cooldown-time (v:frame-time context))))))

;; ;;;;;;;;;
;; Component: asteroid-field
;;
;; The asteroid field simply fires asteroids at the planet in an ever increasing
;; difficulty.
;;;;;;;;;

(v:define-component asteroid-field ()
  ((%pause-p :accessor pause-p
             :initarg :pause-p
             :initform nil)
   (%spawn-period :accessor spawn-period
                  :initarg :spawn-period
                  :initform 1) ;; Hz
   (%cooldown-time :accessor cooldown-time
                   :initarg :cooldown-time
                   :initform 0)
   (%asteroid-holder :accessor asteroid-holder
                     :initarg :asteroid-holder
                     :initform nil)
   (%difficult :accessor difficulty
               :initarg :difficulty
               :initform 1)
   (%difficulty-period :accessor difficulty-period
                       :initarg :difficulty-period
                       :initform 1/10) ;; Hz
   (%difficulty-time :accessor difficulty-time
                     :initarg :difficulty-time
                     :initform 0)
   (%asteroid-db :accessor asteroid-db
                 :initarg :asteroid-db
                 :initform #(("asteroid01-01" 16)
                             ("asteroid02-01" 16)
                             ("asteroid03-01" 16)
                             ("asteroid04-01" 16)
                             ("asteroid05-01" 16)
                             ("asteroid06-01" 16)))
   (%scale-range :accessor scale-range
                 :initarg :scale-range
                 :initform (v2:vec 0.75 1.25))))


(defmethod v:on-component-update ((self asteroid-field))
  (with-accessors ((spawn-period spawn-period)
                   (cooldown-time cooldown-time)
                   (asteroid-holder asteroid-holder)
                   (difficulty difficulty)
                   (difficulty-period difficulty-period)
                   (difficulty-time difficulty-time)
                   (pause-p pause-p)
                   (context v:context)
                   (asteroid-db asteroid-db)
                   (scale-range scale-range))
      self

    (when pause-p
      (return-from v:on-component-update))

    (let ((transform
            (v:component-by-type (v:actor self) 'c/xform:transform)))
      (flet ((ransign (val &optional (offset 0))
               (+ (* (random (if (zerop val) 1 val))
                     (if (zerop (random 2)) 1 -1))
                  offset)))
        (cond
          ((>= cooldown-time (/ (* spawn-period difficulty)))
           (loop :while (>= cooldown-time (/ (* spawn-period difficulty)))
                 :do (decf cooldown-time (/ (* spawn-period difficulty))))

           ;; Find a spot offscreen to start the asteroid
           (let* (origin
                  ;; The target point picked out of the center box in director
                  ;; space that we'll convert to world space.
                  ;;
                  ;; TODO: abstract this to ue a boundary cube.
                  (target
                    (c/xform:transform-point
                     transform
                     (v3:vec (ransign 300.0) (ransign 300.0) 0.1)))
                  (quadrant (random 4)))

             ;; pick an origin point in director space and convert it to world
             ;; space
             (setf origin
                   (c/xform:transform-point
                    transform
                    (ecase quadrant
                      (0 ;; left side
                       (v3:vec -1000.0 (ransign 600.0) 0.1))
                      (1 ;; top side
                       (v3:vec (ransign 1000.0) 600.0 0.1))
                      (2 ;; right side
                       (v3:vec 1000.0 (ransign 600.0) 0.1))
                      (3 ;; bottom side
                       (v3:vec (ransign 1000.0) -600.0 0.1)))))

             (destructuring-bind (name frames)
                 (aref asteroid-db (random (length asteroid-db)))
               (let* ((uniform-scale
                        (+ (aref scale-range 0)
                           (random (- (float (aref scale-range 1) 1.0)
                                      (float (aref scale-range 0) 1.0))))))
                 (make-projectile context
                                  origin
                                  q:+id+
                                  :enemy
                                  :asteroid
                                  :velocity  (ransign 50 400)
                                  ;; this direction is in world space.
                                  ;; it moves from the origin to the target.
                                  :direction (v3:normalize (v3:- target origin))
                                  :scale (v3:vec uniform-scale
                                                 uniform-scale
                                                 uniform-scale)
                                  :name name
                                  :frames frames
                                  :destroy-ttl 4
                                  :parent asteroid-holder)))))

          (t
           (incf cooldown-time (v:frame-time context))))

        ;; Now increase difficulty!
        (cond
          ((>= difficulty-time (/ difficulty-period))
           (loop :while (>= difficulty-time (/ difficulty-period))
                 :do (decf difficulty-time (/ difficulty-period)))

           (incf difficulty 1))

          (t
           (incf difficulty-time (v:frame-time context))))))))

;; ;;;;;;;;;
;; Component: player-stable
;;
;; This component manages a stable of player ships, subtracting or adding to
;; that stable as the player dies (or perhaps gets 1ups).
;; ;;;;;;;;;

;; TODO: This component will have a much different form when we're able to
;; enable/disable actors.

(v:define-component player-stable ()
  ((%max-lives :accessor max-lives
               :initarg :max-lives
               :initform 3)
   (%lives-remaining :accessor lives-remaining
                     :initarg :lives-remaining
                     :initform 3)
   (%stable :accessor stable
            :initarg :stable
            :initform nil)
   ;; TODO: make prefab-descriptor external (and possibly also have a function
   ;; variant. Also have it return a vector instead of a list, more useful
   ;; for indexing.
   (%mockette-prefab :accessor mockette-prefab
                     :initarg :mockette-prefab
                     :initform (v:prefab-descriptor
                                 ("player-ship-mockette" ptp)))

   ;; We keep references to all of the mockettes in an array that matches their
   ;; position on the screen so we can destroy them or re-create them as the
   ;; player dies or gets 1ups.
   (%mockette-refs :accessor mockette-refs
                   :initarg :mockette-refs
                   :initform nil)
   ;; Next one is do increaseing lives grow :left or :right from the origin?
   ;; This is to support two or more player.
   (%direction :accessor direction
               :initarg :direction
               ;; NOTE: Can be :left or :right
               :initform :right)
   ;; How far to place the mockette origins from each other.
   (%width-increment :accessor width-increment
                     :initarg :width-increment
                     :initform 100)))

(defmethod v:on-component-initialize ((self player-stable))
  (setf (mockette-refs self)
        (make-array (max-lives self) :initial-element nil)))

(defun make-mockette (player-stable mockette-index)
  (with-accessors ((mockette-prefab mockette-prefab)
                   (mockette-refs mockette-refs)
                   (width-increment width-increment)
                   (direction direction)
                   (stable stable))
      player-stable
    (let* ((dir (ecase direction (:left -1) (:right 1)))
           (mockette (first
                      (v:make-prefab-instance
                       (v::core (v:context player-stable))
                       mockette-prefab
                       :parent stable)))
           (transform (v:component-by-type mockette 'c/xform:transform)))

      (c/xform:translate
       transform (v3:vec (* mockette-index (* dir width-increment)) -60 0))

      (setf (aref mockette-refs mockette-index) mockette))))

;; This is useful if you want to use the prefab in a player1 or player2
;; configuration. Just change the direction and regenerate it.
(defun regenerate-lives (player-stable)
  (with-accessors ((lives-remaining lives-remaining)
                   (mockette-refs mockette-refs))
      player-stable
    ;; Initialize the stable under the holder with player-remaining mockettes.
    (dotimes (life lives-remaining)
      (when (aref mockette-refs life)
        (v:destroy (aref mockette-refs life)))
      (make-mockette player-stable life))))


(defmethod v:on-component-attach ((self player-stable) actor)
  (declare (ignore actor))
  (regenerate-lives self))

(defun consume-life (player-stable)
  "Remove a life from the stable (which removes it from the display too).
If there are no more lives to remove, return NIL. If there was a life to remove,
return the lives-remaining after the life has been consumed."
  (with-accessors ((lives-remaining lives-remaining)
                   (mockette-refs mockette-refs)
                   (stable stable))
      player-stable

    (when (zerop lives-remaining)
      (return-from consume-life NIL))

    ;; lives-remaining is indexed by one, but the mockettes are indexed by zero.
    (let ((mockette-index (1- lives-remaining)))
      (v:destroy (aref mockette-refs mockette-index))
      (setf (aref mockette-refs mockette-index) nil)
      (decf lives-remaining))
    lives-remaining))

(defun add-life (player-stable)
  (with-accessors ((max-lives max-lives)
                   (lives-remaining lives-remaining)
                   (mockette-prefab mockette-prefab)
                   (mockette-holder mockette-holder)
                   (mockette-refs mockette-refs)
                   (width-increment width-increment)
                   (stable stable))
      player-stable

    (when (eql lives-remaining max-lives)
      ;; You don't get more than max-lives in this implementation.
      (return-from add-life NIL))

    (incf lives-remaining)
    (make-mockette player-stable (1- lives-remaining))))

(defun reset-stable (player-stable)
  (with-accessors ((max-lives max-lives)
                   (lives-remaining lives-remaining))
      player-stable

    (setf lives-remaining max-lives)
    (regenerate-lives player-stable)))


;; ;;;;;;;;;
;; Component: Tags (candidate component for core FL)
;;
;; This component is a registration system for tag symbols that we can insert
;; into this component. This allows us to locate all actors with a certain tag,
;; or query if an actor currently has a certain tag.
;;
;; ;;;;;;;;;

(v:define-component tags ()
  (;; TODO: Technically, this is for initialization only.  I should rename it.
   ;; Also the tags only are present if this component is attached to something.
   ;; So, when looking for "does this component have this tag" I shouldn't just
   ;; MEMBER it out of this list, cause that isn't the point.
   (%tags :accessor tags
          :initarg :tags
          :initform nil))

  (;; In this shared storage, we keep an association between a tag and the actor
   ;; set which uses it, and form each actor to the tag set it has. This allows
   ;; extremely fast lookups in either direction.
   (:db eq)))

;; private API (probably)
(defun tags-refs (context)
  ;; Create the DB if not present.
  (v:with-shared-storage
      (context context)
      ((tag->actors tag->actors/present-p ('tags :db :tag->actors)
                    ;; key: tag, Value: hash table of actor -> actor
                    (u:dict))
       (actor->tags actor->tags/present-p ('tags :db :actor->tags)
                    ;; Key: actor, Value: hash table of tag -> tag
                    (u:dict)))

    (values tag->actors actor->tags)))

(defmethod v:on-component-initialize ((self tags))
  ;; Seed the shared storage cache.
  ;; We're modifying the tags list, so copy-seq it to ensure it isn't a quoted
  ;; list.
  (setf (tags self) (copy-seq (tags self)))
  (tags-refs (v:context self)))

;; private API
(defun %tags-add (self &rest adding-tags)
  (with-accessors ((context v:context)
                   (actor v:actor))
      self
    (u:mvlet ((tag->actors actor->tags (tags-refs context)))
      (dolist (tag adding-tags)
        ;; Add a tag -> actor set link
        (unless (u:href tag->actors tag)
          (setf (u:href tag->actors tag) (u:dict)))
        (setf (u:href tag->actors tag actor) actor)

        ;; Add an actor -> tag set link
        (unless (u:href actor->tags actor)
          (setf (u:href actor->tags actor) (u:dict)))
        (setf (u:href actor->tags actor tag) tag)))))

;; public API
(defun tags-add (self &rest tags)
  "Uniquely add a set of TAGS to the current tags in the SELF instance which
must be a TAGS component."
  (dolist (tag tags)
    (pushnew tag (tags self)))
  (apply #'%tags-add tags))

;; private API
(defun %tags-remove (self &rest removing-tags)
  (with-accessors ((context v:context)
                   (actor v:actor))
      self
    (u:mvlet ((tag->actors actor->tags (tags-refs context)))
      (dolist (tag removing-tags)
        ;; Remove the tag -> actor set link
        (remhash tag (u:href actor->tags actor))
        (when (zerop (hash-table-count (u:href actor->tags actor)))
          (remhash actor actor->tags))

        ;; Remove the actor -> tag set link
        (remhash actor (u:href tag->actors tag))
        (when (zerop (hash-table-count (u:href tag->actors tag)))
          (remhash tag tag->actors))))))

;; public API
(defun tags-remove (self &rest tags)
  "Remove all specified tags from the set of TAGS from the current tags in the
SELF instance which must be a TAGS component."
  (dolist (tag tags)
    (setf (tags self) (remove tag (tags self))))
  (apply #'%tags-remove tags))

;; public API
(defmethod tags-has-tag-p ((self tags) query-tag)
  "Return T if the SELF tags component contains the QUERY-TAG."
  (with-accessors ((context v:context)
                   (actor v:actor))
      self
    (u:mvlet ((tag->actors actor->tags (tags-refs context)))
      (u:href actor->tags actor query-tag))))

;; public API
(defmethod tags-has-tag-p ((self v:actor) query-tag)
  "Return T if there is a tags component on the SELF actor and it also
contains the QUERY-TAG."
  (a:when-let ((tags-component (v:component-by-type self 'tags)))
    (tags-has-tag-p tags-component query-tag)))

;; public API
(defun tags-find-actors-with-tag (context query-tag)
  "Return a list of actors that are tagged with the QUERY-TAG. Return
NIL if no such list exists."
  (u:mvlet ((tag->actors actor->tags (tags-refs context)))
    (a:when-let ((actors (u:href tag->actors query-tag)))
      (u:hash-keys actors))))

(defmethod v:on-component-attach ((self tags) actor)
  (with-accessors ((context v:context)
                   (actor v:actor)
                   (tags tags))
      self
    (dolist (tag tags)
      (%tags-add self tag))))

(defmethod v:on-component-detach ((self tags) actor)
  ;; NOTE: all components are detached before they are destroyed.
  (with-accessors ((context v:context)
                   (actor v:actor)
                   (tags tags))
      self
    (dolist (tag tags)
      (%tags-remove self tag))))

;; ;;;;;;;;;
;; Component: planet
;;
;; Handles hit point management of the planet, plus animations/behavior when it
;; is about to be destroyed.
;;
;; We don't use a hit-points
;;;;;;;;;

(v:define-component planet ()
  ((%transform :accessor transform
               :initarg :transform
               :initform nil)
   (%hit-points :accessor hit-points
                :initarg :hit-points
                :initform nil)
   (%hit-point-warning-threshhold :accessor hit-point-warning-threshhold
                                  :initarg :hit-point-warning-threshhold
                                  :initform 3)
   (%explosion-region :accessor explosion-region
                      :initarg :explosion-region
                      :initform (make-region-ellipsoid (v3:zero)
                                                       100 100 0))
   (%level-manager :accessor level-manager
                   :initarg :level-manager
                   :initform nil)
   (%reported-to-level-manager :accessor reported-to-level-manager
                               :initarg :reported-to-level-manager
                               :initform nil)

   ;; timer stuff
   (%warning-explosion-period :accessor warning-explosion-period
                              :initarg :warning-explosion-period
                              :initform 16) ;; Hz
   (%warning-explosion-timer :accessor warning-explosion-timer
                             :initarg :warning-explosion-timer
                             :initform 0)))

;; TODO: This is naturally a candidate for on-component-attach. However, the
;; on-component-attach for the tags component might not have run so our lookup
;; here fails. This is likely fixable my making the TAGS component go into core,
;; and then having core components run before contrib/user components.  But that
;; still would not work out in compoennts in core unless TAGS was made to run
;; even before those. Need to think a bit.
(defun possibly-report-myself-to-level-manager (planet)
  (with-accessors ((context v:context)
                   (level-manager level-manager)
                   (reported-to-level-manager reported-to-level-manager))
      planet
    ;; TODO: Maybe a change to tags API to shorten this idiomatic code?
    (a:when-let ((actor-lvlmgr
                  (first (tags-find-actors-with-tag context :level-manager))))
      (let ((level-manager
              (v:component-by-type actor-lvlmgr 'level-manager)))

        (unless reported-to-level-manager
          (setf (level-manager planet) level-manager
                reported-to-level-manager t)
          (report-planet-alive (level-manager planet)))))))

(defmethod v:on-component-attach ((self planet) actor)
  (setf (transform self) (v:component-by-type actor 'c/xform:transform)))

(defmethod v:on-component-physics-update ((self planet))
  ;; This might fail for a few frames until things stabilize in the creation of
  ;; the actors and components.  We do it here so it runs at a much slower pace
  ;; than rendering to save effort.
  (possibly-report-myself-to-level-manager self))

(defmethod v:on-component-update ((self planet))
  (with-accessors ((context v:context)
                   (transform transform)
                   (hit-points hit-points)
                   (hit-point-warning-threshhold hit-point-warning-threshhold)
                   (explosion-region explosion-region)
                   (warning-explosion-period warning-explosion-period)
                   (warning-explosion-timer warning-explosion-timer))
      self


    ;; TODO: Notice here we have a conditional running of the timer, how do we
    ;; represent this generically.
    (unless (<= (hp hit-points) hit-point-warning-threshhold)
      (setf warning-explosion-timer 0)
      (return-from v:on-component-update nil))

    (cond
      ;; We exceeded our cooldown time, so time to fire!
      ((>= warning-explosion-timer (/ warning-explosion-period))
       ;; We keep track of time such that we're most accurate in time that we
       ;; next need to fire. NOTE: Technically, this should fire this multiple
       ;; times, but we don't.
       (loop :while (>= warning-explosion-timer (/ warning-explosion-period))
             :do (decf warning-explosion-timer (/ warning-explosion-period)))

       ;; Now, we randomly pick a spot in the ellpsiod, convert it to
       ;; world coordinates, then make an explosion there.
       (flet ((zrandom (val)
                (if (zerop val) 0f0 (float (random val) 1.0))))
         (let* ((er explosion-region)
                (cx (v3:x (center er)))
                (cy (v3:y (center er)))
                (xsign (if (zerop (random 2)) 1f0 -1f0))
                (ysign (if (zerop (random 2)) 1f0 -1f0))
                (local-location
                  ;; Note: In terms of the coordinate space of the planet!
                  (v4:vec (+ cx (float (* (zrandom (x er)) xsign) 1f0))
                          (+ cy (float (* (zrandom (y er)) ysign) 1f0))
                          0f0
                          1f0))
                ;; Figure out where to put the explosion into world space.
                (world-location
                  (c/xform:transform-point transform local-location))
                (world-location (v3:vec (v4:x world-location)
                                        (v4:y world-location)
                                        (dl :planet-warning-explosion)))
                (random-rotation
                  (q:orient :local :z (float (random (* 2 pi)) 1f0)))
                ;; for now, use the same explosions as the planet itself
                (explosion (v:component-by-type (v:actor self) 'explosion)))

           ;; Fix it so I don't do all the work only to discard it if there
           ;; isn't an explosion component.
           (when explosion
             (make-explosion context
                             world-location
                             random-rotation
                             (v3:vec .25 .25 1)
                             :name (name explosion)
                             :frames (frames explosion))))))
      (t
       (incf warning-explosion-timer (v:frame-time context))))))

(defmethod v:on-component-destroy ((self planet))
  (when (level-manager self)
    (report-planet-died (level-manager self))))

;; NOTE: Instead of having just the hit-points be the referent for the planet
;; collider, we have this component be it instead. Then we can redirect the
;; collision to the hit-point component, and also start animations that indicate
;; the planet is about to die when it <= the hit-point-warning-threshhold.
;; Currently, the physics layers are set up so that only enemies can hit the
;; planet.
(defmethod v:on-collision-enter ((self planet) other-collider)
  (with-accessors ((hit-points hit-points)
                   (hit-point-warning-threshhold hit-point-warning-threshhold))
      self
    (possibly-accept-damage hit-points other-collider)
    (possibly-auto-destroy hit-points)
    nil))

;; ;;;;;;;;;
;; Component: time-keeper
;;
;; The purpose of this component is to draw the time display so the user can see
;; it going to zero. When it reaches zero, the score is tallied, the level will
;; be over, and you'll move to the next level. This component takes care of
;; both keeping track of the time left in the level, and also managing the
;; display on the screen. It also has an interface in order to determine if the
;; time has been all used up.
;; ;;;;;;;;;

(v:define-component time-keeper ()
  ((%pause :accessor pause
           :initarg :pause
           :initform t)
   (%time-max :accessor time-max
              :initarg :time-max
              :initform 10f0) ;; seconds
   (%time-left :accessor time-left
               :initarg :time-left
               :initform 0f0) ;; seconds
   (%time-bar-transform :accessor time-bar-transform
                        :initarg :time-bar-transform
                        :initform nil)
   (%time-bar-height-scale :accessor time-bar-height-scale
                           :initarg :time-bar-height-scale
                           :initform 512f0)
   (%time-bar-width :accessor time-bar-width
                    :initarg :time-bar-width
                    :initform 16f0)
   (%time-bar-renderer :accessor time-bar-renderer
                       :initarg :time-bar-renderer
                       :initform nil)
   (%time-bar-full-color :accessor time-bar-full-color
                         :initarg :time-bar-full-color
                         :initform (v4:vec 0 1 0 1))
   (%time-bar-empty-color :accessor time-bar-empty-color
                          :initarg :time-bar-empty-color
                          :initform (v4:vec 1 0 0 1))))

(defmethod v:on-component-initialize ((self time-keeper))
  (setf (time-left self) (time-max self)))


;; We really don't need to do this per frame.
(defmethod v:on-component-physics-update ((self time-keeper))
  (with-accessors ((context v:context)
                   (pause pause)
                   (time-max time-max)
                   (time-left time-left)
                   (time-bar-renderer time-bar-renderer)
                   (time-bar-width time-bar-width)
                   (time-bar-full-color time-bar-full-color)
                   (time-bar-empty-color time-bar-empty-color)
                   (time-bar-transform time-bar-transform)
                   (time-bar-height-scale time-bar-height-scale))
      self

    (when pause
      (return-from v:on-component-physics-update nil))

    ;; TODO: Bug, it seems a fast physics-update can happen before the user
    ;; protocol is properly set up. Debug why this can be NIL in a 120Hz physics
    ;; update period.
    (unless time-bar-transform
      (return-from v:on-component-physics-update nil))

    (let ((how-far-to-empty (- 1f0 (/ time-left time-max))))

      ;; Size the time bar in accordance to how much time is left.
      (c/xform:scale time-bar-transform
                  (v3:vec time-bar-width
                          (a:lerp how-far-to-empty
                                  time-bar-height-scale
                                  0f0)
                          1f0)
                  :replace-p t)

      ;; Color the time bar in accordance to how much time is left.
      (let ((material (c/render:material time-bar-renderer)))
        (setf (v:uniform-ref material :mix-color)
              (v4:lerp time-bar-full-color time-bar-empty-color
                       how-far-to-empty)))

      ;; Account the time that has passed
      ;; TODO: make a utility macro called DECF-CLAMP
      (decf time-left (v:delta context))
      (when (<= time-left 0f0)
        (setf time-left 0f0))

      )))

(defun time-keeper-out-of-time-p (self)
  (zerop (time-left self)))

;; ;;;;;;;;;
;; Component: level-manager
;;
;; The purpose of this component is to:
;; A: Turn the asteroid field on and off (off meaning destroy all asteroids)
;; B: Turn enemy generation on and off (off meanins gestroy all enemies/bullets)
;; C: Know how many planets there are and detect game over if all gone.
;;
;; ;;;;;;;;;

(v:define-component level-manager ()
  ((%time-keeper :accessor time-keeper
                 :initarg :time-keeper
                 :initform nil)
   (%asteroid-field :accessor asteroid-field
                    :initarg :asteroid-field
                    :initform nil)
   (%enemy-generator :accessor enemy-generator
                     :initarg :enemy-generator
                     :initform nil)
   (%reporting-planets :accessor reporting-planets
                       :initarg :reporting-planets
                       :initform 0)
   (%dead-planets :accessor dead-planets
                  :initarg :dead-planets
                  :initform 0)))

(defun level-out-of-time-p (level-manager)
  (time-keeper-out-of-time-p (time-keeper level-manager)))

(defun pause-time-keeper (level-manager)
  (setf (pause (time-keeper level-manager)) t))

(defun unpause-time-keeper (level-manager)
  (setf (pause (time-keeper level-manager)) nil))

(defun report-planet-alive (level-manager)
  (incf (reporting-planets level-manager)))

(defun report-planet-died (level-manager)
  (incf (dead-planets level-manager)))

(defun pause-asteroid-field (level-manager)
  (setf (pause-p (asteroid-field level-manager)) t))

(defun unpause-asteroid-field (level-manager)
  (setf (pause-p (asteroid-field level-manager)) nil))

(defun pause-enemy-generation (level-manager)
  ;; Not implemented yet.
  (declare (ignore level-manager))
  nil)

(defun unpause-enemy-generation (level-manager)
  ;; Not implemented yet.
  (declare (ignore level-manager))
  nil)

(defun destroy-all-asteroids (level-manager)
  ;; Not implemented yet.
  (declare (ignore level-manager))
  nil)

(defun destroy-all-enemies (level-manager)
  ;; Not implemented yet.
  (declare (ignore level-manager))
  nil)

(defun destroy-all-enemy-bullets (level-manager)
  ;; Not implemented yet.
  (declare (ignore level-manager))
  nil)

(defun destroy-active-opponents (level-manager)
  (destroy-all-asteroids level-manager)
  (destroy-all-enemies level-manager)
  (destroy-all-enemy-bullets level-manager))

(defun all-planets-dead-p (level-manager)
  ;; if we have zero planets technically none of them are dead.
  (and (plusp (reporting-planets level-manager))
       (= (dead-planets level-manager)
          (reporting-planets level-manager))))


;; ;;;;;;;;;
;; Component: director
;;
;; The director component runs the entire game, ensuring to move between
;; states of the game, notice and replace the player when they die
;;;;;;;;;

;; The director manages the overall state the game is in, plus it
;; micromanages the playing state to ensure fun ensues. Each state is
;; non-blocking and manages a distinct state in which the game may be.
;;
;; state-machine:
;;
;; <start>
;;   |
;;   v
;; :waiting-to-play -> :quit
;;   |
;;   v
;; :level-spawn
;;   |
;;   v
;; :player-spawn -> :game-over
;;   |
;;   v
;; :playing -> :player-spawn | :level-complete | :quit
;;   |
;;   v
;; :game-over -> :waiting-to-play | :quit
;;   |
;;   v
;; :initials-entry -> :waiting-to-play | :quit
;;
;; :level-complete -> :level-spawn | :quit
;;
;; :quit
;;   |
;;   v
;; <terminate>
;;

(v:define-component director ()
  ((%current-game-state :accessor current-game-state
                        :initarg :current-game-state
                        :initform :waiting-to-play)
   (%previous-game-state :accessor previous-game-state
                         :initarg :previous-game-state
                         :initform nil)
   ;; The db of levels over which the game progresses.
   (%levels :accessor levels
            :initarg :levels
            :initform (v:prefab-descriptor
                        ("level-0" ptp)
                        ("level-1" ptp)
                        ("level-2" ptp)))
   ;; which level is considered the demo level.
   (%demo-level :accessor demo-level
                :initarg :demo-level
                :initform (v:prefab-descriptor
                            ("demo-level" ptp)))
   ;; Which level are we playing?
   (%current-level :accessor current-level
                   :initarg :current-level
                   :initform 0)
   ;; The actual root instance of the actor for the current level.
   (%current-level-ref :accessor current-level-ref
                       :initarg :current-level-ref
                       :initform nil)
   ;; This is the parent of the levels when they are instantiated.
   (%level-holder :accessor level-holder
                  :initarg :level-holder
                  :initform nil)
   ;; When we spawn the level, this is the reference to the level-manager
   ;; component for that specific level
   (%level-manager :accessor level-manager
                   :initarg :level-manager
                   :initform nil)
   ;; The stable from which we know we can get another player.
   (%player-1-stable :accessor player-1-stable
                     :initarg :player-1-stable
                     :initform nil)
   ;; When we instantiate a player, this is the place it goes.
   (%current-player-holder :accessor current-player-holder
                           :initarg :current-player-holder
                           :initform nil)
   ;; And a reference to the actual player instance
   (%current-player :accessor current-player
                    :initarg :current-player
                    :initform nil)

   ;; Timer
   ;; When we respawn a player, we wait max-wait-time before they show up.
   (%player-respawn-max-wait-time :accessor player-respawn-max-wait-time
                                  :initarg :player-respawn-max-wait-time
                                  :initform .5f0) ;; seconds
   (%player1-respawn-timer :accessor player1-respawn-timer
                           :initarg :player1-respawn-timer
                           :initform 0)
   (%player1-waiting-for-respawn :accessor player1-waiting-for-respawn
                                 :initarg :player1-waiting-for-respawn
                                 :initform nil)

   ;; Timer
   ;; When we enter game over, this is how long to show the gameover sign.
   (%game-over-max-wait-time :accessor game-over-max-wait-time
                             :initarg :game-over-max-wait-time
                             :initform 2) ;; seconds
   (%game-over-timer :accessor game-over-timer
                     :initarg :game-over-timer
                     :initform 0)

   ;; Timer
   ;; When we complete a level we show the level complete sign for a bit before
   ;; Moving to the next level.
   (%level-complete-max-wait-time :accessor level-complete-max-wait-time
                                  :initarg :level-complete-max-wait-time
                                  :initform 3) ;; seconds
   (%level-complete-timer :accessor level-complete-timer
                          :initarg :level-complete-timer
                          :initform 0)))

;; each method returns the new state it should do for the next update.
(defgeneric process-director-state (director state previous-state))

;; From here, we dispatch to the state management GF.
(defmethod v:on-component-update ((self director))
  (with-accessors ((current-game-state current-game-state)
                   (previous-game-state previous-game-state)
                   (levels levels)
                   (demo-level demo-level)
                   (current-level current-level)
                   (level-holder level-holder)
                   (current-player-holder current-player-holder))
      self

    (let (new-game-state)
      (setf new-game-state
            (process-director-state self current-game-state previous-game-state)

            previous-game-state current-game-state

            current-game-state new-game-state))))

(defmethod process-director-state ((self director)
                                   (state (eql :waiting-to-play))
                                   previous-state)
  (with-accessors ((context v:context)
                   (demo-level demo-level)
                   (current-level current-level)
                   (current-level-ref current-level-ref)
                   (level-holder level-holder)
                   (player-1-stable player-1-stable))
      self
    (let ((next-state :waiting-to-play))
      ;; When we've just transitioned to this state from not itself, it means
      ;; we need to do the work to show the demo level.
      (unless (eq state previous-state)
        ;; 0. If there is a player (like maybe you beat the game), destroy it.
        (a:when-let ((players (tags-find-actors-with-tag context :player)))
          (dolist (player players)
            (v:destroy player)))

        ;; 1. Spawn the demo-level which includes the PtP sign and press play
        ;; to start.

        (when current-level-ref
          ;; Whatever was previously there, get rid of.
          (v:destroy current-level-ref))

        (setf current-level-ref
              (first (v:make-prefab-instance
                      (v::core context)
                      demo-level
                      :parent level-holder)))

        ;; 2. ensure the lives player1-stable is set to max if not already so.
        (when (/= (lives-remaining player-1-stable)
                  (max-lives player-1-stable))
          ;; TODO: If this happens first frame, something goes wrong. FIXME.
          ;; The TODO is why the WHEN guard is around this line.
          (reset-stable player-1-stable)))


      ;; 3. We always listen for the start button so we can play a game.
      (when (v:input-enter-p context '(:gamepad1 :start))
        (setf current-level 0 ;; start at beginning of level progression
              next-state :level-spawn))

      next-state)))

(defmethod process-director-state ((self director)
                                   (state (eql :level-spawn))
                                   previous-state)
  (with-accessors ((context v:context)
                   (current-game-state current-game-state)
                   (levels levels)
                   (demo-level demo-level)
                   (current-level current-level)
                   (current-level-ref current-level-ref)
                   (level-manager level-manager)
                   (level-holder level-holder)
                   (current-player-holder current-player-holder))
      self

    ;; Destroy old level, if any.
    (when current-level-ref
      (v:destroy current-level-ref)
      (setf current-level-ref nil))

    ;; spawn current level requested
    (setf current-level-ref
          (first (v:make-prefab-instance
                  (v::core context)
                  ;; TODO: Odd requirement for the LIST here given how I access
                  ;; this prefab description.
                  (list (nth current-level levels))
                  :parent level-holder)))

    ;; find this level's level-manager and keep a reference to it
    (let ((lvlmgr (v:component-by-type current-level-ref 'level-manager)))
      (setf level-manager lvlmgr))

    :player-spawn))


(defmethod process-director-state ((self director)
                                   (state (eql :player-spawn))
                                   previous-state)
  (with-accessors ((context v:context)
                   (current-player-holder current-player-holder)
                   (current-player current-player)
                   (player-1-stable player-1-stable)
                   (player-respawn-max-wait-time player-respawn-max-wait-time)
                   (player1-respawn-timer player1-respawn-timer)
                   (player1-waiting-for-respawn player1-waiting-for-respawn))
      self

    (let ((next-state :playing)
          (player-alive-p (tags-find-actors-with-tag context :player)))

      ;; TODO: If the player is alive, tell it it can move again (even if it
      ;; already can).
      (when (not player-alive-p)
        (if (not (eq state previous-state))
            (setf player1-respawn-timer 0
                  next-state :player-spawn)
            (if (>= player1-respawn-timer player-respawn-max-wait-time)
                ;; We're waiting for respawn, and the time has come.
                ;; Create the player.
                (let ((player-life (consume-life player-1-stable)))
                  (if (null player-life)
                      ;; out of players!
                      (setf next-state :game-over)
                      (let ((new-player-instance
                              (first (v:make-prefab-instance
                                      (v::core context)
                                      '(("player-ship" ptp))
                                      :parent current-player-holder))))
                        ;; TODO: make player respawn in same place and
                        ;; orientation as where they died.

                        ;; Store the new player, and implicitly go to the
                        ;; unchanged next-state.
                        (setf current-player new-player-instance))))
                (progn
                  (incf player1-respawn-timer (v:frame-time context))
                  (setf next-state :player-spawn)))))

      next-state)))

(defmethod process-director-state ((self director)
                                   (state (eql :playing))
                                   previous-state)

  (with-accessors ((context v:context)
                   (current-game-state current-game-state)
                   (levels levels)
                   (demo-level demo-level)
                   (current-level current-level)
                   (level-holder level-holder)
                   (level-manager level-manager)
                   (player-1-stable player-1-stable)
                   (current-player-holder current-player-holder)
                   (current-player current-player))
      self

    (unless (eq state previous-state)
      ;; When we enter this state, we must unpause the timer.
      (unpause-time-keeper level-manager))

    (cond
      ((not (tags-find-actors-with-tag context :player))
       ;; When we leave, we pause, since we don't want to penalize the player
       ;; by removing time when they can't possibly be playing.
       (pause-time-keeper level-manager)
       :player-spawn)

      ;; Yay! level complete!
      ((level-out-of-time-p level-manager)
       (pause-time-keeper level-manager)
       :level-complete)

      ;; otherwise, user is continuing play.
      (t
       :playing))))

(defmethod process-director-state ((self director)
                                   (state (eql :level-complete))
                                   previous-state)
  (with-accessors ((context v:context)
                   (levels levels)
                   (demo-level demo-level)
                   (current-level current-level)
                   (level-manager level-manager)
                   (level-holder level-holder)
                   (level-complete-timer level-complete-timer)
                   (level-complete-max-wait-time level-complete-max-wait-time)
                   (current-player-holder current-player-holder))
      self

    (unless (eq state previous-state)
      (setf level-complete-timer 0)

      ;; First: turn off asteroid generator.
      ;;
      ;; NOTE: We never unpase it, since by definition it'll be destroyed
      ;; and remade when we load a new (or demo) level).
      (pause-asteroid-field level-manager)

      ;; Second: Abruptly destroy all :dangerous things.
      (let ((dangerous-actors (tags-find-actors-with-tag context :dangerous)))
        (dolist (dangerous-actor dangerous-actors)
          (v:destroy dangerous-actor)))

      ;; TODO: If the player is alive, tell it it can't move.
      ;; and possibly reset it to home position.


      ;; Spawn game-over sign and set to destroy in max-time seconds
      (let ((level-complete-sign
              (first (v:make-prefab-instance
                      (v::core context)
                      '(("level-complete-sign" ptp))))))
        (v:destroy-after-time level-complete-sign
                              :ttl level-complete-max-wait-time)))

    (cond
      ((>= level-complete-timer level-complete-max-wait-time)
       ;; If we reached the end of the timer, do this:
       (cond
         ;; TODO: We assume there is at least one non demo level.
         ((= current-level (1- (length levels))) ;; We're on last level.
          ;; we completed the last level of the game, YAY!, go back to
          ;; waiting to play. (maybe stick a YOU WIN! state in here too) and
          ;; reset our level progression.
          (setf current-level 0)
          ;; We reached the end of game, technically game over, but we'll just
          ;; restart.
          :waiting-to-play)
         (t
          (incf current-level)
          ;; TODO: if the player is still alive, tell it it can move again.
          :level-spawn)))

      (t
       ;; Keep waiting for the timer to fire.
       (incf level-complete-timer (v:frame-time context))
       :level-complete))))



(defmethod process-director-state ((self director)
                                   (state (eql :game-over))
                                   previous-state)
  (with-accessors ((context v:context)
                   (levels levels)
                   (demo-level demo-level)
                   (current-level current-level)
                   (level-holder level-holder)
                   (game-over-max-wait-time game-over-max-wait-time)
                   (game-over-timer game-over-timer)
                   (current-player-holder current-player-holder))
      self

    ;; If there is a player then destroy it, we'll let the rest of the state
    ;; machine deal with it resetting the internal state.
    (a:when-let ((player (first (tags-find-actors-with-tag context :player))))
      (v:destroy player))

    (unless (eq state previous-state)
      (setf game-over-timer 0)
      (let ((game-over-sign
              (first (v:make-prefab-instance
                      (v::core context)
                      '(("game-over-sign" ptp))))))
        (v:destroy-after-time game-over-sign :ttl game-over-max-wait-time)))

    (cond
      ((>= game-over-timer game-over-max-wait-time)
       :waiting-to-play)
      (t
       (incf game-over-timer (v:frame-time context))
       :game-over))))

(defmethod process-director-state ((self director)
                                   (state (eql :initials-entry))
                                   previous-state)

  (with-accessors ((current-game-state current-game-state)
                   (levels levels)
                   (demo-level demo-level)
                   (current-level current-level)
                   (level-holder level-holder)
                   (current-player-holder current-player-holder))
      self
    :initials-entry))


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Prefabs
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(v:define-prefab "projectile" (:library ptp)
  "A generic projectile that can be a bullet, or an asteroid, or whatever."
  (projectile :transform (v:ref :self :component 'c/xform:transform)
              :mover (v:ref :self :component 'line-mover)
              :collider (v:ref :self :component 'c/col:sphere)
              :sprite (v:ref :self :component 'c/sprite:sprite)
              :action (v:ref :self :component 'c/action:actions))
  (tags :tags '(:dangerous))
  (damage-points :dp 1)
  (explosion :name "explode01-01" :frames 15)
  (hit-points :hp 1)
  (line-mover)
  (c/sprite:sprite :spec :spritesheet-data)
  (c/col:sphere :center (v3:zero)
                :on-layer :enemy-bullet
                :referent (v:ref :self :component 'hit-points)
                :radius 15)
  (c/render:render :material 'sprite-sheet
                   :mode :sprite)
  (c/action:actions :default '((:type x/action:sprite-animate
                                :duration 0.5
                                :repeat-p t))))

(v:define-prefab "player-ship" (:library ptp)
  "The venerable Player Ship. Controls how it looks, collides, and movement."
  (tags :tags '(:player))
  (explosion :name "explode04-01" :frames 15
             :scale (v3:vec 2f0 2f0 2f0))
  (damage-points :dp 1)
  (hit-points :hp 1
              ;; When the player is born, they are automatically invulnerable
              ;; for 1 second.
              ;; TODO: NEED(!) to visualize this effect!
              :invulnerability-timer 1)
  (player-movement)
  (c/col:sphere :center (v3:zero)
                :on-layer :player
                :referent (v:ref :self :component 'hit-points)
                :radius 30)
  ("ship-body"
   (c/sprite:sprite :spec :spritesheet-data
                    :name "ship26")
   (c/render:render :material 'sprite-sheet
                    :mode :sprite)
   ("center-gun"
    (c/xform:transform :translate (v3:zero))
    (gun :physics-layer :player-bullet
         :depth-layer :player-bullet
         :name "bullet01" :frames 2))

   ("exhaust"
    (c/xform:transform :translate (v3:vec 0 -60 0))
    (c/sprite:sprite :spec :spritesheet-data
                     :name "exhaust03-01"
                     :frames 8)
    (c/render:render :material 'sprite-sheet
                     :mode :sprite)
    (c/action:actions :default '((:type x/action:sprite-animate
                                  :duration 0.5
                                  :repeat-p t))))))

(v:define-prefab "player-ship-mockette" (:library ptp)
  "An image of the ship, but no colliders or guns."
  (c/sprite:sprite :spec :spritesheet-data
                   :name "ship26")
  (c/render:render :material 'sprite-sheet
                   :mode :sprite))

(v:define-prefab "player-stable" (:library ptp)
  ;; TODO: Clarify when we actually need the / infront of the actor name during
  ;; use of V:REF. Here is seems we DON'T need one, but sometimes we do!
  (player-stable :stable (v:ref "stable-holder"))
  ("stable-holder"))

(v:define-prefab "generic-planet" (:library ptp)
  (planet :hit-points (v:ref :self :component 'hit-points))
  (hit-points :hp 5)
  (explosion :name "explode03-01" :frames 15
             :scale (v3:vec 3f0 3f0 3f0))
  (c/col:sphere :center (v3:zero)
                :on-layer :planet
                :referent (v:ref :self :component 'planet)
                :visualize t
                :radius 145)
  (c/sprite:sprite :spec :spritesheet-data
                   :name "planet01")
  (c/render:render :material 'sprite-sheet
                   :mode :sprite))

(v:define-prefab "generic-explosion" (:library ptp)
  (explosion :sprite (v:ref :self :component 'c/sprite:sprite))
  (c/sprite:sprite :spec :spritesheet-data
                   ;; TODO: When this is misnamed, the error is extremely obscure
                   :name "explode01-01"
                   :frames 15)
  (c/render:render :material 'sprite-sheet
                   :mode :sprite)
  (c/action:actions :default '((:type x/action:sprite-animate
                                :duration 0.5
                                :repeat-p nil))))

;; TODO: Refactor these signs into a single prefab and a sign component to
;; manage the configuration of the prefab.
(v:define-prefab "warning-wave-sign" (:library ptp)
  "Not used yet."
  (c/xform:transform :translate (v3:vec 0 0 (dl :sign))
                     :scale 512f0)
  ("sign"
   (c/smesh:static-mesh :location '((:core :mesh) "plane.glb"))
   (c/render:render :material 'warning-wave)))

(v:define-prefab "warning-mothership-sign" (:library ptp)
  "Not used yet."
  (c/xform:transform :translate (v3:vec 0 0 (dl :sign))
                     :scale 512f0)
  ("sign"
   (c/smesh:static-mesh :location '((:core :mesh) "plane.glb"))
   (c/render:render :material 'warning-mothership)))

(v:define-prefab "title-sign" (:library ptp)
  (c/xform:transform :translate (v3:vec 0 0 (dl :sign))
                     :scale 512f0)
  ("sign"
   (c/smesh:static-mesh :location '((:core :mesh) "plane.glb"))
   (c/render:render :material 'title)))

(v:define-prefab "game-over-sign" (:library ptp)
  (c/xform:transform :translate (v3:vec 0 0 (dl :sign))
                     :scale 512f0)
  ("sign"
   (c/smesh:static-mesh :location '((:core :mesh) "plane.glb"))
   (c/render:render :material 'game-over)))

(v:define-prefab "level-complete-sign" (:library ptp)
  (c/xform:transform :translate (v3:vec 0 0 (dl :sign))
                     :scale 512f0)
  ("sign"
   (c/smesh:static-mesh :location '((:core :mesh) "plane.glb"))
   (c/render:render :material 'level-complete)))

(v:define-prefab "starfield" (:library ptp)
  ("bug-todo:implicit-transform:see-trello"
   (c/xform:transform :scale 960
                      ;; NOTE: ortho projection, so we can put starfield way
                      ;; back.
                      :translate (v3:vec 0 0 (dl :starfield)))
   (c/smesh:static-mesh :location '((:core :mesh) "plane.glb"))
   (c/render:render :material 'starfield)))

(v:define-prefab "time-keeper" (:library ptp)
  ("bug-todo:implicit-transform:see-trello"
   (c/xform:transform :translate (v3:vec 900 -512 (dl :time-keeper)))
   (time-keeper :time-max 30f0
                :time-bar-transform (v:ref "time-bar-root"
                                           :component 'c/xform:transform)
                :time-bar-renderer (v:ref "time-bar-root/time-display"
                                          :component 'c/render:render))
   ("time-bar-root"
    ;; When we scale the transform for this object, the alignment of the
    ;; time-bar will cause it to stretch upwards from a "ground" at 0 in this
    ;; coordinate frame.
    ("time-display"
     (c/xform:transform :translate (v3:vec 0 1 0))
     (c/smesh:static-mesh :location '((:core :mesh) "plane.glb"))
     ;; TODO: when 'time-bar is mis-spelled in the material,
     ;; I don't get the debug material, why?
     ;; TODO: I think this material is leaked when this object is destroyed.
     (c/render:render :material `(time-bar ,(gensym "TIME-BAR-MATERIAL-")))))))

(v:define-prefab "demo-level" (:library ptp)
  (level-manager :asteroid-field (v:ref :self :component 'asteroid-field))
  (tags :tags '(:level-manager))
  (asteroid-field :asteroid-holder (v:ref "/demo-level/asteroids"))

  (("starfield" :link ("/starfield" :from ptp)))
  ("asteroids")
  (("title" :copy ("/title-sign" :from ptp))
   (c/xform:transform :translate (v3:vec 0 0 (dl :sign))
                   ;; TODO: BUG: the scale in the original transform
                   ;; should have been preserved.
                   :scale 512f0)))

(v:define-prefab "level-0" (:library ptp)
  (level-manager :asteroid-field (v:ref :self :component 'asteroid-field)
                 :time-keeper
                 (v:ref "time-keeper/bug-todo:implicit-transform:see-trello"
                        :component 'time-keeper))
  (tags :tags '(:level-manager))
  (asteroid-field :asteroid-holder (v:ref "/level-2/asteroids"))
  ("asteroids")
  (("starfield" :link ("/starfield" :from ptp)))
  (("time-keeper" :link ("/time-keeper" :from ptp)))
  (("planet-0" :link ("/generic-planet" :from ptp))
   (c/xform:transform :translate (v3:vec 0 100 (dl :planet))
                   :scale 0.9f0)
   (c/sprite:sprite :spec :spritesheet-data
                       :name "planet01"))
  (("planet-1" :link ("/generic-planet" :from ptp))
   (c/xform:transform :translate (v3:vec -200 -100 (dl :planet))
                   :scale 0.9f0)
   (c/sprite:sprite :spec :spritesheet-data
                       :name "planet02"))
  (("planet-2" :link ("/generic-planet" :from ptp))
   (c/xform:transform :translate (v3:vec 200 -100 (dl :planet))
                   :scale 0.9f0)
   (c/sprite:sprite :spec :spritesheet-data
                       :name "planet03")))

(v:define-prefab "level-1" (:library ptp)
  (level-manager :asteroid-field (v:ref :self :component 'asteroid-field)
                 :time-keeper
                 (v:ref "time-keeper/bug-todo:implicit-transform:see-trello"
                        :component 'time-keeper))
  (tags :tags '(:level-manager))
  (asteroid-field :asteroid-holder (v:ref "/level-1/asteroids"))
  ("asteroids")
  (("starfield" :link ("/starfield" :from ptp)))
  (("time-keeper" :link ("/time-keeper" :from ptp)))
  (("planet-0" :link ("/generic-planet" :from ptp))
   (c/xform:transform :translate (v3:vec -200 100 (dl :planet))
                   :scale 0.9f0)
   (c/sprite:sprite :spec :spritesheet-data
                       :name "planet01"))
  (("planet-1" :link ("/generic-planet" :from ptp))
   (c/xform:transform :translate (v3:vec 200 100 (dl :planet))
                   :scale 0.9f0)
   (c/sprite:sprite :spec :spritesheet-data
                       :name "planet02")))

(v:define-prefab "level-2" (:library ptp)
  (level-manager :asteroid-field (v:ref :self :component 'asteroid-field)
                 :time-keeper
                 (v:ref "time-keeper/bug-todo:implicit-transform:see-trello"
                        :component 'time-keeper))
  (tags :tags '(:level-manager))
  (asteroid-field :asteroid-holder (v:ref "/level-0/asteroids"))
  ("asteroids")
  (("starfield" :link ("/starfield" :from ptp)))
  (("time-keeper" :link ("/time-keeper" :from ptp)))
  (("planet-0" :link ("/generic-planet" :from ptp))
   (c/xform:transform :translate (v3:vec 0 100 (dl :planet))
                   :scale 0.9f0)
   (c/sprite:sprite :spec :spritesheet-data
                       :name "planet01")))


(v:define-prefab "protect-the-planets" (:library ptp)
  "The top most level prefab which has the component which drives the game
sequencing."
  (c/xform:transform :scale (v3:one))
  (director :level-holder (v:ref "/protect-the-planets/current-level")
            :player-1-stable (v:ref "/protect-the-planets/player-1-stable"
                                    :component 'player-stable))

  (("camera" :copy ("/cameras/ortho" :from ptp-base))
   (c/xform:transform :translate (v3:vec 0 0 (dl :camera))))

  (("player-1-stable" :link ("/player-stable" :from ptp))
   (c/xform:transform
    :translate (v3:vec -900 550 (dl :player-stable))))

  ("current-level"))


(v:define-prefab "starfield-demo" (:library ptp)
  "A simple demo scene of the starfield. Not used in the game, but for
testing the starfield shader."

  (("starfield" :link ("/starfield" :from ptp)))

  (("camera" :copy ("/cameras/ortho" :from ptp-base))
   (c/xform:transform :translate (v3:vec 0 0 (dl :camera)))))

;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Prefab descriptors for convenience
;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(v:define-prefab-descriptor ptp ()
  ("protect-the-planets" ptp))

(v:define-prefab-descriptor starfield-demo ()
  ("starfield-demo" ptp))
