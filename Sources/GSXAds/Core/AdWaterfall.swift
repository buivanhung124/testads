import Foundation
import GSXCore

/// Thử lần lượt từng id cho tới khi có quảng cáo.
///
/// Đây là chỗ khác hẳn bản UIKit. Bên đó `countTier` xoay vòng *mỗi lần gọi*:
/// lần này id A, lần sau id B — A không lấp được thì chịu, phải đợi lượt gọi
/// sau mới tới B. Ở đây A hỏng thì B được thử ngay trong cùng một lần, nên
/// danh sách nhiều id mới thật sự là một tầng dự phòng.
enum AdWaterfall {

    struct Loaded<Ad> {
        let ad: Ad
        let unitId: String
    }

    static func load<Ad>(
        ids: [String],
        format: AdType,
        using loader: (String) async throws -> Ad
    ) async throws -> Loaded<Ad> {

        guard !ids.isEmpty else { throw AdError.noAdUnitId }
        var lastError: Error = AdError.noAdUnitId

        for (index, unitId) in ids.enumerated() {
            do {
                let ad = try await loader(unitId)
                if index > 0 {
                    GSXLog.debug("[\(format.rawValue)] lấp được ở id thứ \(index + 1)/\(ids.count)")
                }
                return Loaded(ad: ad, unitId: unitId)
            } catch {
                lastError = error
                GSXLog.debug("[\(format.rawValue)] id \(index + 1)/\(ids.count) hỏng: \(error.localizedDescription)")
            }
        }

        throw lastError
    }
}
