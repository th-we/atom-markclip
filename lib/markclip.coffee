fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
md5 = require 'md5'
PKG = require '../package.json'
{CompositeDisposable} = require 'atom'

TAG_TEXT_EDITOR = 'ATOM-TEXT-EDITOR'
SAVE_TYPE_BASE64 = 'base64'
SAVE_TYPE_FILE = 'file'
SAVE_TYPE_FILE_IN_FOLDER = 'file in folder'
SAVE_TYPE_DEFAULT_FOLDER = 'default folder'
SAVE_TYPE_CUSTOM_FILE = 'custom file'
SPACE_REPLACER = '-';
SPACE_REG = /\s+/g;

module.exports = Markclip =
  config:
    saveType:
      type: 'string'
      description: 'Where to save the clipboard image file'
      default: SAVE_TYPE_BASE64
      enum: [SAVE_TYPE_BASE64, SAVE_TYPE_FILE, SAVE_TYPE_FILE_IN_FOLDER, SAVE_TYPE_DEFAULT_FOLDER, SAVE_TYPE_CUSTOM_FILE]
      order: 10
    folderSpaceReplacer:
      type: 'string'
      description: 'A charset to replace spaces in image folder name'
      default: SPACE_REPLACER
      order: 20
    defaultFolder:
      type: 'string'
      description: "A folder to save image, use with `saveType = #{SAVE_TYPE_DEFAULT_FOLDER}`"
      default: 'img'
      order: 30
    fileExt:
      type: 'array'
      description: 'File extensions of markdown files'
      default: ['.md', '.markdown', '.mdown', '.mkd', '.mkdown']
      order: 40


  handleInsertEvent: (e) ->
    textEditor = atom.workspace.getActiveTextEditor()
    # do nothing if there is no ActiveTextEditor
    return if !textEditor

    # CHECK: do nothing if no image
    clipboard = require('electron').clipboard
    img = clipboard.readImage()
    if img.isEmpty()
      e.abortKeyBinding()
      return

    fileExt = atom.config.get('markclip.fileExt')

    # CHECK: do nothing with unsaved file
    filePath = textEditor.getPath()
    if not filePath
      atom.notifications.addWarning(PKG.name + ': Markdown file NOT saved', {
        detail: 'save your file as ' + fileExt.map((n) => '"' + n + '"').join(', ')
      })
      return

    # CHECK: file type should in fileExt
    filePathObj = path.parse(filePath)
    return if fileExt.indexOf(filePathObj.ext) < 0

    saveType = atom.config.get('markclip.saveType')
    # atom 1.12 img.toDataURL / atom 1.11 img.toDataUrl
    imgDataURL = if img.toDataURL then img.toDataURL() else img.toDataUrl()
    # IF:saveType: SAVE AS A FILE
    if saveType == SAVE_TYPE_FILE_IN_FOLDER || saveType == SAVE_TYPE_FILE || saveType == SAVE_TYPE_DEFAULT_FOLDER
      imgFileDir = filePathObj.dir
      # IF:saveType: SAVE IN FOLDER or SAVE IN DEFAULT FOLDER, create it
      if saveType == SAVE_TYPE_FILE_IN_FOLDER || saveType == SAVE_TYPE_DEFAULT_FOLDER
        folderSpaceReplacer = atom.config.get('markclip.folderSpaceReplacer').replace(SPACE_REG, '') || SPACE_REPLACER;
        folderName = if saveType == SAVE_TYPE_FILE_IN_FOLDER then filePathObj.name else atom.config.get('markclip.defaultFolder');
        imgFileDir = path.join(imgFileDir, folderName.replace(SPACE_REG, folderSpaceReplacer))
        mkdirp.sync(imgFileDir)
      # create file with md5 name
      imgFilePath = path.join(imgFileDir, @getDefaultImageName(imgDataURL))
      imgPNG = if img.toPNG then img.toPNG() else img.toPng()
      fs.writeFileSync(imgFilePath, imgPNG);
      @insertImgIntoEditor(textEditor, path.relative(filePathObj.dir, imgFilePath).replace(/\\/g, '/'))
    # IF:saveType: CUSTOM FILE
    else if saveType == SAVE_TYPE_CUSTOM_FILE
      newItemPath = atom.applicationDelegate.showSaveDialog({
        defaultPath: path.join(filePathObj.dir, @getDefaultImageName(imgDataURL))
      })
      if newItemPath
        imgPNG = if img.toPNG then img.toPNG() else img.toPng()
        fs.writeFileSync(newItemPath, imgPNG);
        @insertImgIntoEditor(textEditor, path.relative(filePathObj.dir, newItemPath.replace(/\\/g, '/')))
    # IF:saveType: SAVE AS BASE64
    else
      @insertImgIntoEditor(textEditor, imgDataURL)

  insertImgIntoEditor: (textEditor, src) ->
    textEditor.insertText("![](#{src})\n")
  getDefaultImageName: (imgDataURL) ->
    return md5(imgDataURL).replace('=', '') + '.png'

  subscriptions: null
  activate: (state) ->
    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'markclip:insert': (e) => @handleInsertEvent(e)
    @subscriptions.add atom.config.observe 'markclip.saveType', (val) ->
      saveType = val
    @subscriptions.add atom.config.observe 'markclip.folderSpaceReplacer', (val) ->
      folderSpaceReplacer = val

    # atom.contextMenu.add {
    #   'atom-text-editor': [{
    #     label: 'Bookmark-----',
    #     command: 'my-package:toggle'
    #   }]
    # }
    # console.log 'abc'

  deactivate: ->
    @subscriptions.dispose()
