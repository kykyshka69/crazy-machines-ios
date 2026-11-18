import Foundation

@main
struct PortableSmoke {
 static func main() throws {
  // Bottom-left origin, two pixels: red then blue, both RGB24 in BGR storage.
  var tga=[UInt8](repeating:0,count:18)
  tga[2]=2;tga[12]=2;tga[14]=1;tga[16]=24
  tga += [0,0,255,255,0,0]
  let decoded=try CMTGATexture(data:Data(tga))
  precondition(decoded.width==2 && decoded.height==1)
  precondition(Array(decoded.rgba)==[255,0,0,255,0,0,255,255])
  do {
   _=try CMTGATexture(data:Data(tga.dropLast()))
   fatalError("Truncated TGA accepted")
  } catch CMTGAError.truncated {}
  let json="""
  {"summary":{"models":1,"named_slots":1,"matrix_bindings":1,"unique_names":1},
   "attachments":[{"model":"balloon.ucm","group":0,"slot":0,"name":"Rope","matrix_index":0,
    "matrix_row_major":[[1,0,0,0],[0,1,0,0],[0,0,1,0],[0.25,0,0,1]],
    "translation_candidate":[0.25,0,0]}]}
  """
  let catalog=try CMAttachmentCatalog(data:Data(json.utf8))
  precondition(catalog.slots(model:"BALLOON.UCM").count==1)
  precondition(catalog.slots(model:"balloon.ucm",group:1).isEmpty)
  print("Portable Swift smoke tests passed: TGA decode, truncation, catalog validation, lookup.")
 }
}
