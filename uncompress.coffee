fs = require "fs"
child_process = require "child_process"
dir = process.argv[2]
wrench = require "wrench"
async = require "async"
path = require "path"



extractMethods = {
    ".rar":"mkdir '{folder}';unrar e  -cl '{filename}' '{folder}'"
    ,".zip":"mkdir '{folder}';unzip '{filename}' -d '{folder}'"
    ,".7z":"mkdir '{folder}';7z x -o'{folder}' '{filename}'"
    ,".pdf":"mkdir '{folder}';convert -density 128 '{filename}' '{folder}/{firstname}.jpg'"}
#escapeBash = (str = "")->
#    return str.replace new RegExp("['\"\\\\#]","ig"),(match)->
#        return "\\"+match
uncompress = (dir,recursive,done)->
    if recursive
        files = wrench.readdirSyncRecursive dir
    else
        files = fs.readdirSync dir
    files = files.filter (item)->
        ext = path.extname item
        return extractMethods[ext] or (recursive and fs.lstatSync(path.join(dir,item)).isDirectory())
    console.log "scan files"
    console.log files
    async.forEachSeries files,((file,callback)->
        file = path.join dir,file
        try
            state = fs.lstatSync file
        catch e
            console.log "error",e
            callback()
            return
        if state.isDirectory()
            uncompress(file,recursive,callback)
            return
        console.log "extracting",file
        ext = path.extname file
        folder = path.resolve path.join(dir,path.basename(file).replace(ext,""))
        firstname = path.basename(file).replace(ext,"")
        cmd = extractMethods[ext].replace(/{filename}/g,file).replace(/{folder}/g,folder).replace(/{firstname}/,firstname)
        console.log cmd
        extractProcess = child_process.exec cmd
        extractProcess.stdout.pipe process.stdout
        extractProcess.stderr.pipe process.stderr
        process.stdin.pipe extractProcess.stdin
        process.stdin.on "error",(err)->
            console.error "err in stdin",err
        extractProcess.stdin.on "error",(err)->
            console.error "err in extract stdin",err
        extractProcess.on "exit",(code)->
            extractProcess.stdout.unpipe()
            extractProcess.stderr.unpipe()
            process.stdin.unpipe(extractProcess.stdin)
            if code isnt 0
                console.log "fail to extract file %s code:%d",file,code 
                callback()
            else 
                console.log "successfully extract to %s",folder
                console.log "remove original file",file 
                fs.unlinkSync file
                if recursive
                    uncompress(folder,recursive,callback)
                else
                    callback() 
        ),(err)->
            setTimeout (()->
                done()
                ),500
if not dir
    console.log "usage: coffee uncompress.coffee {dirname}"
else
    uncompress dir,true,()->
        setTimeout (()->
            console.log "done"
            process.kill(0)
            ),500