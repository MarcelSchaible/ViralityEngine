(asdf:defsystem #:virality.engine
  :description "An experimental game engine."
  :author ("Michael Fiano <mail@michaelfiano.com>"
           "Peter Keller <psilord@cs.wisc.edu>")
  :maintainer ("Michael Fiano <mail@michaelfiano.com>"
               "Peter Keller <psilord@cs.wisc.edu>")
  :license "MIT"
  :homepage "https://github.com/hackertheory/ViralityEngine"
  :bug-tracker "https://github.com/hackertheory/ViralityEngine/issues"
  :source-control (:git "https://github.com/hackertheory/ViralityEngine.git")
  :encoding :utf-8
  :depends-on (#:alexandria
               #:babel
               #:cl-graph
               #:cl-opengl
               #:cl-ppcre
               #:closer-mop
               #:doubly-linked-list
               #:fast-io
               #:glsl-packing
               #:golden-utils
               #:jsown
               #:origin
               #:queues.simple-cqueue
               #:sdl2
               #:sdl2-image
               #:split-sequence
               #:static-vectors
               #:trivial-features
               #:uiop
               #:varjo
               #:verbose)
  :pathname "src"
  :serial t
  :components
  (
   (:file "package-actions")
   (:file "package-actors")
   (:file "package-colliders")
   (:file "package-components")
   (:file "package-extensions")
   (:file "package-geometry")
   (:file "package-gpu")
   (:file "package-image")
   (:file "package-input")
   (:file "package-materials")
   (:file "package-prefab")
   (:file "package-shader")
   (:file "package-textures")
   (:file "package-engine")
   (:file "package-nicknames")
   (:file "common")
   (:file "interactive-development")
   (:file "debugging")
   (:file "metadata")
   (:file "deployment")
   (:file "binary-parser")
   (:file "geometry-static")
   (:file "geometry-dynamic-attribute")
   (:file "geometry-dynamic-group")
   (:file "geometry-dynamic-buffer")
   (:file "geometry-dynamic")
   (:file "uuid")
   (:file "resource")
   (:file "context")
   (:file "options")
   (:file "logging")
   (:file "graph")
   (:file "flow")
   (:file "shared-storage")
   (:file "attributes")
   (:file "actor")
   (:file "mop-component")
   (:file "component")
   (:file "protocol-collider")
   (:file "protocol-component")
   (:file "protocol-rcache")
   (:file "object-query")
   (:file "hardware-query")
   (:file "annotations")
   (:file "clock")
   (:file "display")
   (:file "input-keyboard")
   (:file "input-mouse")
   (:file "input-gamepad")
   (:file "input-window")
   (:file "input-states")
   (:file "input")
   (:file "shaders")
   (:file "colliders")
   (:file "action")
   (:file "action-fade")
   (:file "action-rotate")
   (:file "action-sprite-animate")
   (:file "gpu-shader")
   (:file "gpu-common")
   (:file "gpu-functions")
   (:file "gpu-stages")
   (:file "gpu-program")
   (:file "gpu-packing")
   (:file "gpu-attributes")
   (:file "gpu-uniforms")
   (:file "gpu-layout")
   (:file "gpu-blocks")
   (:file "gpu-buffers")
   (:file "image")
   (:file "image-sdl2")
   (:file "texture-common")
   (:file "texture")
   (:file "texture-1d")
   (:file "texture-2d")
   (:file "texture-3d")
   (:file "texture-1d-array")
   (:file "texture-2d-array")
   (:file "texture-cube-map")
   (:file "texture-cube-map-array")
   (:file "texture-rectangle")
   (:file "texture-buffer")
   (:file "materials")
   (:file "component-transform")
   (:file "component-actions")
   (:file "component-camera")
   (:file "component-camera-following")
   (:file "component-camera-tracking")
   (:file "component-mesh-dynamic")
   (:file "component-mesh-static")
   (:file "component-render")
   (:file "component-sprite")
   (:file "component-collider")
   (:file "prefab-common")
   (:file "prefab-checks")
   (:file "prefab-parser")
   (:file "prefab-loader")
   (:file "prefab-reference")
   (:file "prefab-descriptor")
   (:file "prefab")
   (:file "core")
   (:file "engine")

   (:file "shader/common")
   (:file "shader/common-swizzle")
   (:file "shader/common-vari")
   (:file "shader/common-math")
   (:file "shader/common-structs")
   (:file "shader/color-grading")
   (:file "shader/color-space")
   (:file "shader/graphing")
   (:file "shader/shaping-iq")
   (:file "shader/shaping-levin")
   (:file "shader/shaping-penner")
   (:file "shader/shaping-misc")
   (:file "shader/hashing-bbs")
   (:file "shader/hashing-fast32")
   (:file "shader/hashing-fast32-2")
   (:file "shader/noise-cellular")
   (:file "shader/noise-hermite")
   (:file "shader/noise-perlin")
   (:file "shader/noise-polkadot")
   (:file "shader/noise-simplex")
   (:file "shader/noise-value")
   (:file "shader/noise-misc")
   (:file "shader/sdf-2d")
   (:file "shader/texture")
   (:file "shader/sprite")
   (:file "shader/visualization-collider")

   (:file "definition/annotations")
   (:file "definition/graphs")
   (:file "definition/flows")
   (:file "definition/texture-profiles")
   (:file "definition/textures")
   (:file "definition/material-profiles")
   (:file "definition/materials")))
