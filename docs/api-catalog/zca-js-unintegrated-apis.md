# 📋 Danh Sách Các API zca-js Chưa Tích Hợp Lại

Tài liệu này tổng hợp và phân loại các API còn lại (trong tổng số 149 APIs) của thư viện **`zca-js`** chưa được tích hợp thực tế vào **Alpha CRM**. Đây là cẩm nang hữu ích để đội ngũ phát triển tham khảo khi có nhu cầu mở rộng hoặc nâng cấp các tính năng tự động hóa Zalo cá nhân trong tương lai.

---

## 👥 1. Nhóm API Quản Trị Nhóm (Group Administration)
Alpha CRM hiện tại mới chỉ hỗ trợ Đọc danh sách nhóm và Rời nhóm. Zalo cá nhân còn hỗ trợ các quyền quản trị nhóm cực kỳ mạnh mẽ khác:

*   **`createGroup(groupName, memberUids)`**: Tạo một nhóm Zalo mới tự động với danh sách thành viên được chỉ định ban đầu.
*   **`addUserToGroup(userUid, groupId)`**: Thêm một hoặc nhiều thành viên vào nhóm chat hiện tại.
*   **`removeUserFromGroup(userUid, groupId)`**: Trực xuất một thành viên ra khỏi nhóm (chỉ dành cho Trưởng/Phó nhóm).
*   **`changeGroupName(groupId, newName)`** & **`changeGroupAvatar(groupId, avatarPath)`**: Tự động thay đổi tên nhóm hoặc ảnh đại diện nhóm.
*   **`addGroupDeputy(groupId, userUid)`** & **`removeGroupDeputy(groupId, userUid)`**: Bổ nhiệm hoặc bãi miễn chức danh Phó nhóm.
*   **`changeGroupOwner(groupId, newUserUid)`**: Chuyển nhượng quyền Trưởng nhóm cho một thành viên khác.
*   **`addGroupBlockedMember(groupId, userUid)`** & **`removeGroupBlockedMember(groupId, userUid)`**: Quản lý danh sách đen (Blacklist) các thành viên bị chặn không cho tham gia lại nhóm.
*   **`enableGroupLink(groupId)`** & **`disableGroupLink(groupId)`**: Bật hoặc tắt link tham gia nhóm công khai (Link gia nhập nhanh).
*   **`upgradeGroupToCommunity(groupId)`**: Nâng cấp nhóm chat thường thành nhóm Cộng đồng (quy mô lên tới hàng nghìn thành viên).

---

## 💬 2. Nhóm API Tin Nhắn Đa Phương Tiện & Tương Tác (Rich Messaging & Interactions)
Hiện tại Alpha CRM mới chỉ hỗ trợ gửi tin nhắn văn bản (Text) thô. `zca-js` hỗ trợ các định dạng tin nhắn nâng cao:

*   **`uploadAttachment(filePath)`**: Tải một file bất kỳ (PDF báo giá, file zip, tài liệu word...) lên máy chủ Zalo để lấy link đính kèm.
*   **`sendSticker(stickerId, recipientId, threadType)`**: Gửi nhãn dán động Zalo để tăng tương tác thân thiện với khách hàng.
*   **`sendVideo(videoPath, recipientId, threadType)`** & **`sendVoice(voicePath, recipientId, threadType)`**: Gửi tin nhắn video hoặc tin nhắn thoại ghi âm sẵn.
*   **`sendCard(userUid, recipientId, threadType)`**: Gửi danh thiếp (Contact Card) của một tài khoản Zalo khác cho khách hàng.
*   **`sendBankCard(bankData, recipientId, threadType)`**: Gửi thông tin tài khoản ngân hàng dưới dạng thẻ trực quan (Card) để khách hàng tiện chuyển khoản thanh toán.
*   **`undo(messageId, threadId, isGroup)`**: Thu hồi tin nhắn đã gửi (chỉ áp dụng trong khoảng thời gian Zalo cho phép).
*   **`deleteMessage(messageId, threadId, isGroup)`**: Xóa tin nhắn ở phía màn hình người gửi để dọn dẹp lịch sử.

---

## 🤝 3. Nhóm API Quản Lý Bạn Bè & CRM (Friendship & CRM Queries)
Alpha CRM đã hỗ trợ tự động duyệt kết bạn theo thời gian thực (Realtime Auto-Approve). Bạn có thể tham khảo thêm các tính năng sau:

*   **`sendFriendRequest(userUid, message)`**: Tự động gửi lời mời kết bạn kèm lời nhắn giới thiệu dịch vụ đến một số điện thoại hoặc UID.
*   **`rejectFriendRequest(userUid)`**: Từ chối yêu cầu kết bạn được gửi đến.
*   **`removeFriend(userUid)`**: Hủy kết bạn (Xóa liên hệ).
*   **`undoFriendRequest(userUid)`**: Thu hồi lời mời kết bạn đã gửi đi khi chưa được bên kia đồng ý.
*   **`blockUser(userUid)`** & **`unblockUser(userUid)`**: Chặn hoặc bỏ chặn liên lạc một người dùng.
*   **`getFriendOnlines()`**: Lấy danh sách bạn bè đang trực tuyến (Online) trên Zalo để ưu tiên gửi tin nhắn tư vấn ngay.
*   **`getFriendRecommendations()`**: Lấy danh sách gợi ý kết bạn của Zalo.
*   **`getMultiUsersByPhones(phoneNumbers[])`**: Tra cứu hàng loạt số điện thoại xem số nào đã đăng ký Zalo để phân loại dữ liệu khách hàng tiềm năng.

---

## 📊 4. Nhóm API Tiện Ích Tương Tác (Polls, Reminders & Notes)
Các tính năng chăm sóc khách hàng và ghi nhớ lịch hẹn trong nhóm chat:

*   **`createPoll(title, options[], groupId)`**: Tạo cuộc bình chọn (Poll) trong nhóm chat Zalo (ví dụ: bình chọn thời gian họp, khảo sát ý kiến khách hàng).
*   **`votePoll(pollId, optionIds[])`** & **`lockPoll(pollId)`**: Tham gia bình chọn hoặc khóa bình chọn.
*   **`createReminder(title, timestamp, uids[], groupId)`**: Tạo nhắc nhở lịch hẹn tự động (ví dụ: nhắc lịch thanh toán, lịch bảo trì) cho các thành viên trong nhóm.
*   **`createNote(title, content, groupId)`**: Tạo ghi chú ghim lên đầu nhóm chat để các thành viên dễ dàng cập nhật thông tin quan trọng.

---

## 🏪 5. Nhóm API Bán Hàng & Danh Mục Shop (Business & Catalog features)
Hỗ trợ quản lý danh mục sản phẩm Zalo Shop trực tiếp từ tài khoản cá nhân:

*   **`createCatalog(catalogName)`** & **`deleteCatalog(catalogId)`**: Tạo hoặc xóa danh mục sản phẩm.
*   **`createProductCatalog(productData)`** & **`updateProductCatalog(productId, productData)`**: Thêm mới hoặc cập nhật thông tin sản phẩm (tên, mô tả, giá bán, hình ảnh) trong cửa hàng cá nhân.
*   **`uploadProductPhoto(imagePath)`**: Tải ảnh sản phẩm lên Zalo Shop.

---

## 👍 6. Nhóm API Biểu Cảm & Thống Kê (Reactions & Feed)
*   **`addReaction(emojiIcon, messageId, threadId, isGroup)`**: Thả cảm xúc (Tim, Like, Haha, Phẫn nộ...) vào một tin nhắn cụ thể của khách hàng để tạo sự thân mật.
*   **`updateProfile(profileData)`** & **`updateProfileBio(bioText)`**: Tự động cập nhật thông tin cá nhân (Tên, ngày sinh, giới tính) hoặc dòng giới thiệu (Bio) của tài khoản Zalo.
