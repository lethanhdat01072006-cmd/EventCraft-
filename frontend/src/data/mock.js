// Dữ liệu giả để làm UI khi backend của Ngọc chưa sẵn sàng.
export const MOCK_CATEGORIES = [
  { id: 1, name: 'Tiệc cưới', description: 'Nhà hàng, trang trí, MC' },
  { id: 2, name: 'Sinh nhật', description: 'Tiệc sinh nhật mọi lứa tuổi' },
  { id: 3, name: 'Hội nghị', description: 'Hội thảo, sự kiện doanh nghiệp' },
  { id: 4, name: 'Team building', description: 'Gắn kết đội nhóm' },
  { id: 5, name: 'Chụp ảnh & quay phim', description: 'Ghi lại khoảnh khắc' },
  { id: 6, name: 'Âm thanh & ánh sáng', description: 'Thiết bị và kỹ thuật' },
];

export const MOCK_VENDORS = [
  { id: 1, name: 'Hoa Sen Event', location: 'Đà Nẵng', rating: 4.9, eventsDone: 120 },
  { id: 2, name: 'Sơn Trà Studio', location: 'Đà Nẵng', rating: 4.8, eventsDone: 85 },
  { id: 3, name: 'Bình Minh Sound', location: 'Hội An', rating: 4.7, eventsDone: 64 },
  { id: 4, name: 'Cầu Vàng Catering', location: 'Đà Nẵng', rating: 4.6, eventsDone: 97 },
];

export const MOCK_SERVICES = [
  { id: 1, name: 'Trọn gói tiệc cưới 200 khách', vendorName: 'Hoa Sen Event', categoryId: 1, location: 'Đà Nẵng', rating: 4.9, price: 45000000, oldPrice: 52000000, discountPercent: 13 },
  { id: 2, name: 'Trang trí sinh nhật chủ đề biển', vendorName: 'Hoa Sen Event', categoryId: 2, location: 'Đà Nẵng', rating: 4.7, price: 3500000 },
  { id: 3, name: 'Hội nghị 100 người trọn gói', vendorName: 'Cầu Vàng Catering', categoryId: 3, location: 'Đà Nẵng', rating: 4.5, price: 18000000, oldPrice: 20000000, discountPercent: 10 },
  { id: 4, name: 'Team building bãi biển Mỹ Khê', vendorName: 'Bình Minh Sound', categoryId: 4, location: 'Đà Nẵng', rating: 4.8, price: 9500000 },
  { id: 5, name: 'Gói chụp ảnh cưới ngoại cảnh', vendorName: 'Sơn Trà Studio', categoryId: 5, location: 'Hội An', rating: 4.9, price: 12000000 },
  { id: 6, name: 'Dàn âm thanh ánh sáng sân khấu', vendorName: 'Bình Minh Sound', categoryId: 6, location: 'Hội An', rating: 4.6, price: 6000000, oldPrice: 7500000, discountPercent: 20 },
  { id: 7, name: 'Tiệc sinh nhật bé 30 khách', vendorName: 'Cầu Vàng Catering', categoryId: 2, location: 'Huế', rating: 4.4, price: 5200000 },
  { id: 8, name: 'Quay phim sự kiện công ty', vendorName: 'Sơn Trà Studio', categoryId: 5, location: 'Đà Nẵng', rating: 4.3, price: 4000000 },
];
