import libespeak_ng
class EspeakNGService {
    var directory: String = ""
    var internalStorage = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path()
    static let shared = EspeakNGService()
    private init(){
        copyEspeakDataToInternalStorage()
    }
    
    func copyEspeakDataToInternalStorage(){
        if let directoryURL = copyDirectoryToDocuments(directoryName: "espeak-ng-data") {
            let directoryPath = directoryURL.path
            directory = directoryPath
            UserDefaults.standard.set(directoryURL.path, forKey: "CopiedDirectoryPath")
        }
    }
    
    func set_espeak_initialize_callback() -> Int{
        
        let internalStorageCString = strdup(internalStorage)
        let res = libespeak_ng.espeak_Initialize(AUDIO_OUTPUT_SYNCHRONOUS, 300, internalStorageCString, 0)
        libespeak_ng.espeak_SetVoiceByName("en");
        if internalStorageCString != nil {
            free(internalStorageCString)
        }
        return Int(res)
    }
    
    func set_espeak_text_to_phonemes_callback(text: String) -> String{
        let utf8CString = text.utf8CString // Includes null terminator
        var phonemeResult = ""
        // Pass pointer-to-pointer to the function
        utf8CString.withUnsafeBufferPointer { bufferPointer in
            guard let baseAddress = bufferPointer.baseAddress else {
                print("Failed to get base address")
                return
            }
            
            // Create a pointer to the base address (const void**)
            var rawPointer: UnsafeRawPointer? = UnsafeRawPointer(baseAddress)
            
            // Allocate a pointer to that pointer
            withUnsafeMutablePointer(to: &rawPointer) { textPtr in
                let result = libespeak_ng.espeak_TextToPhonemes(
                    textPtr as UnsafeMutablePointer<UnsafeRawPointer?>,
                    espeakCHARS_UTF8,
                    24322
                )
                
                if let result = result {
                    let phonemes = String(cString: result)
                    print("Phoneme output:", phonemes)
                    phonemeResult = phonemes 
                } else {
                    print("Phoneme conversion failed")
                }
            }
        }
        return phonemeResult
    }
}

func copyDirectoryToDocuments(directoryName: String) -> URL? {
    
    guard let sourcePath = Bundle.main.path(forResource: directoryName, ofType: nil) else {
        print("Directory \(directoryName) not found in bundle")
        return nil
    }
    
    let sourceURL = URL(fileURLWithPath: sourcePath)
    
    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let destinationURL = documentsDirectory.appendingPathComponent(directoryName)
    
    do {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }
        
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    } catch {
        print("Error copying directory: \(error)")
        return nil
    }
}

