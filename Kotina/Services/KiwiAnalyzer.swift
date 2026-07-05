import Foundation
import KiwiC

struct KiwiToken: Equatable, Sendable {
    let form: String
    let tag: String
    let range: Range<String.Index>
    let typoCost: Float
}

protocol KoreanAnalyzing: Sendable {
    func analyze(_ text: String) throws -> [KiwiToken]
}

final class KiwiAnalyzer: KoreanAnalyzing, @unchecked Sendable {
    private let handle: kiwi_h

    init(modelPath: String) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelPath, isDirectory: &isDirectory),
              isDirectory.boolValue,
              let handle = kiwi_init(
                  modelPath,
                  -1,
                  Int32(KIWI_BUILD_DEFAULT | KIWI_BUILD_MODEL_TYPE_CONG),
                  Int32(KIWI_DIALECT_STANDARD)
              ) else {
            throw TextProcessingError.localEngineUnavailable
        }
        self.handle = handle
    }

    deinit {
        kiwi_close(handle)
    }

    func analyze(_ text: String) throws -> [KiwiToken] {
        var option = kiwi_analyze_option_t()
        option.match_options = Int32(KIWI_MATCH_ALL_WITH_NORMALIZING)
        option.allowed_dialects = Int32(KIWI_DIALECT_STANDARD)
        option.dialect_cost = 3
        option.typo_threshold = 2.5

        let utf16Text = Array(text.utf16) + [0]
        let result = utf16Text.withUnsafeBufferPointer { buffer in
            kiwi_analyze_w(handle, buffer.baseAddress, 1, option, nil)
        }
        guard let result else {
            throw TextProcessingError.localEngineUnavailable
        }
        defer { kiwi_res_close(result) }

        let tokenCount = kiwi_res_word_num(result, 0)
        guard tokenCount >= 0 else {
            throw TextProcessingError.localEngineUnavailable
        }

        return try (0..<Int(tokenCount)).map { tokenIndex in
            try makeToken(result: result, tokenIndex: Int32(tokenIndex), text: text)
        }
    }

    private func makeToken(
        result: kiwi_res_h,
        tokenIndex: Int32,
        text: String
    ) throws -> KiwiToken {
        guard let formPointer = kiwi_res_form(result, 0, tokenIndex),
              let tagPointer = kiwi_res_tag(result, 0, tokenIndex),
              let info = kiwi_res_token_info(result, 0, tokenIndex)?.pointee,
              let range = stringRange(
                  utf16Offset: Int(info.chr_position),
                  length: Int(info.length),
                  in: text
              ) else {
            throw TextProcessingError.localEngineUnavailable
        }

        return KiwiToken(
            form: String(cString: formPointer),
            tag: String(cString: tagPointer),
            range: range,
            typoCost: info.typo_cost
        )
    }

    private func stringRange(
        utf16Offset: Int,
        length: Int,
        in text: String
    ) -> Range<String.Index>? {
        let utf16 = text.utf16
        guard let lowerUTF16 = utf16.index(
            utf16.startIndex,
            offsetBy: utf16Offset,
            limitedBy: utf16.endIndex
        ),
        let upperUTF16 = utf16.index(
            lowerUTF16,
            offsetBy: length,
            limitedBy: utf16.endIndex
        ),
        let lowerBound = String.Index(lowerUTF16, within: text),
        let upperBound = String.Index(upperUTF16, within: text) else {
            return nil
        }
        return lowerBound..<upperBound
    }
}
