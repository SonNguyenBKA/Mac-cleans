enum CleanConfirmText {
    static func message(includesTrash: Bool) -> String {
        var s = "Chuyển vào Thùng rác: khôi phục được, nhưng chưa giải phóng dung lượng cho tới khi dọn Thùng rác.\nXoá vĩnh viễn: giải phóng dung lượng ngay, KHÔNG khôi phục được."
        if includesTrash { s += "\nCác mục đang nằm trong Thùng rác luôn bị xoá vĩnh viễn." }
        return s
    }
}
