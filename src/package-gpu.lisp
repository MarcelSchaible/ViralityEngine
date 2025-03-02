(in-package #:cl-user)

(defpackage #:virality.gpu
  (:use #:cl)
  (:export
   #:define-function
   #:define-struct
   #:define-macro
   #:define-shader
   #:load-shaders
   #:unload-shaders
   #:recompile-shaders
   #:with-shader
   #:view-source
   #:create-block-alias
   #:find-block
   #:bind-block
   #:unbind-block
   #:buffer-name
   #:find-buffer
   #:create-buffer
   #:bind-buffer
   #:unbind-buffer
   #:delete-buffer
   #:read-buffer-path
   #:write-buffer-path
   #:uniforms
   #:uniform-int
   #:uniform-int-array
   #:uniform-float
   #:uniform-float-array
   #:uniform-vec2
   #:uniform-vec2-array
   #:uniform-vec3
   #:uniform-vec3-array
   #:uniform-vec4
   #:uniform-vec4-array
   #:uniform-mat2
   #:uniform-mat2-array
   #:uniform-mat3
   #:uniform-mat3-array
   #:uniform-mat4
   #:uniform-mat4-array))
