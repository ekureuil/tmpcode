Stuff to do:

+ Scene Tree:
  - Geometry
  - Node
  -> Both are Spatials (taken from jmonkey)
  
  - A Spatial has: 
     - a local transform / quaternion
     - a world transform / quaternion
  
  - Each time a Spatial local transform changes, flag it to be updated
  - On update, traverse the tree and update world transform for sub-tree of Spatial flagged to be updated.
  
+ Update loop: how about // update ?

| Common (fps, scene tree copy) / Gui / input   | | |
|-----------------------------------------------|-|-| 
| Scene Tree  updater  |  game loop | physics ? |
| Rendering            |
  
For a // loop to work:
 + Each thread must work on local data:
   - scene tree must be copied (deep copy too ... quite expensive)
   - same for game loop + physics if physics is on a different thread
=> It seems to not be a good candidate for //ism

+ Materials:
 - fragment shader
 - vertex shader
 - geometry
 
+ Automatic batching of geometries with same material ?

