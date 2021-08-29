# foguete
Luajit demo framework based on [emoon/rocket](https://github.com/emoon/rocket) and [opengl-with-luajit](https://bitbucket.org/jimbo00000/opengl-with-luajit/src/master/)

![foguete Logo](foguete.png)

Foguete is Portuguese for 'rocket'. It provides a Luajit module for interacting with [rocket](https://github.com/emoon/rocket) and all the pieces for creating a graphical demo with synched music.

## Instructions


### Editing
Launch the editor app: `bin/GLeditor.exe`  
on Linux:
```
$ LD_LIBRARY_PATH=external/bass/linux/ ./t2-output/linux-gcc-release-default/editor
```

Press **ctrl-o** in editor to open a file of rocket keyframes(e.g., `data/kfs.rocket`)
- Linux: type file path in console. **Ctrl-1**,2,3,4 are shortcuts for last used files.



### Graphics

Launch luajit with `main_glfw` and the `sync` parameter.

`bin\windows\luajit main_demo.lua sync` 

`$ LD_LIBRARY_PATH=./bin/linux/x64 ./bin/linux/x64/luajit main_demo.lua sync`

Drive the demo with keys and mouse control in editor while the demo is connected via socket.  
Press space in the editor to play/pause.  
Scrub with the mousewheel.  
Edit.  
Repeat.  

Add new scene files to the `scene/` directory, and their names to `graphics.lua` here: [graphics.lua#L7](https://github.com/jimbo00000/foguete/blob/master/scene/graphics.lua#L7)

Add new variable values for editing in rocket here: [graphics.lua#L18](https://github.com/jimbo00000/foguete/blob/master/scene/graphics.lua#L18)

Replace the included music with your own by editing the values at the top of `main_demo.lua`.  

### Release

```
luajit main_demo.lua compo
```
