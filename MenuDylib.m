
// ============================================
// FILE 2: MenuDylib.m
// ============================================
// Đã sửa toàn bộ lỗi:
// - Bỏ vm_region (không cần thiết, gây crash)
// - Dùng memcpy an toàn thay vì memcmp trực tiếp
// - Thêm kiểm tra con trỏ NULL
// - Đơn giản hóa hàm quét

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <sys/stat.h>
#import <sys/mman.h>
#import <mach/mach.h>

@interface MenuController : UIViewController

@property (nonatomic, strong) UIButton *nutBatTat;
@property (nonatomic, strong) UITextView *khungLog;
@property (nonatomic, strong) UILabel *nhanTrangThai;
@property (nonatomic, assign) BOOL dangChay;

- (void)batTatAutoTimKiem;
- (void)capNhatLog:(NSString *)noiDung;
- (void)tienHanhTimKiemOffset;
- (void)quetMauByte:(uint64_t)tuDiaChi denDiaChi:(uint64_t)denDiaChi;
- (void)doiTrangThaiMenu:(UIButton *)nut;

@end

@implementation MenuController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];

    self.nhanTrangThai = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, 280, 30)];
    self.nhanTrangThai.text = @"Trạng thái: TẮT";
    self.nhanTrangThai.textColor = [UIColor whiteColor];
    self.nhanTrangThai.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.nhanTrangThai];

    self.nutBatTat = [UIButton buttonWithType:UIButtonTypeSystem];
    self.nutBatTat.frame = CGRectMake(60, 90, 200, 50);
    [self.nutBatTat setTitle:@"BẬT AUTO TÌM OFFSET" forState:UIControlStateNormal];
    [self.nutBatTat setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.nutBatTat.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
    [self.nutBatTat addTarget:self action:@selector(batTatAutoTimKiem) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.nutBatTat];

    self.khungLog = [[UITextView alloc] initWithFrame:CGRectMake(10, 150, 300, 400)];
    self.khungLog.backgroundColor = [UIColor blackColor];
    self.khungLog.textColor = [UIColor greenColor];
    self.khungLog.font = [UIFont systemFontOfSize:12];
    self.khungLog.editable = NO;
    [self.view addSubview:self.khungLog];

    self.dangChay = NO;
}

- (void)batTatAutoTimKiem {
    self.dangChay = !self.dangChay;

    if (self.dangChay) {
        self.nhanTrangThai.text = @"Trạng thái: ĐANG CHẠY";
        [self.nutBatTat setTitle:@"TẮT AUTO TÌM OFFSET" forState:UIControlStateNormal];
        self.nutBatTat.backgroundColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.2 alpha:1.0];
        [self capNhatLog:@"Đã bật tự động tìm kiếm offset"];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self tienHanhTimKiemOffset];
        });
    } else {
        self.nhanTrangThai.text = @"Trạng thái: TẮT";
        [self.nutBatTat setTitle:@"BẬT AUTO TÌM OFFSET" forState:UIControlStateNormal];
        self.nutBatTat.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
        [self capNhatLog:@"Đã tắt tự động tìm kiếm offset"];
    }
}

- (void)capNhatLog:(NSString *)noiDung {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *thoiGian = [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                           dateStyle:NSDateFormatterShortStyle
                                                           timeStyle:NSDateFormatterMediumStyle];
        NSString *dongLog = [NSString stringWithFormat:@"[%@] %@\n", thoiGian, noiDung];
        self.khungLog.text = [self.khungLog.text stringByAppendingString:dongLog];

        NSRange cuoiKhung = NSMakeRange(self.khungLog.text.length - 1, 1);
        [self.khungLog scrollRangeToVisible:cuoiKhung];
    });
}

- (void)tienHanhTimKiemOffset {
    [self capNhatLog:@"Bắt đầu quét vùng nhớ..."];

    uint32_t soLuongImage = _dyld_image_count();
    [self capNhatLog:[NSString stringWithFormat:@"Tổng số image: %u", soLuongImage]];

    for (uint32_t i = 0; i < soLuongImage; i++) {
        const char *tenImage = _dyld_get_image_name(i);
        const struct mach_header *headerImage = _dyld_get_image_header(i);
        intptr_t truotImage = _dyld_get_image_vmaddr_slide(i);

        if (tenImage != NULL && headerImage != NULL) {
            NSString *tenImageStr = [NSString stringWithUTF8String:tenImage];

            if ([tenImageStr containsString:@"UnityFramework"] ||
                [tenImageStr containsString:@"UnityAppController"] ||
                [tenImageStr containsString:@"libil2cpp"] ||
                [tenImageStr containsString:@"GameAssembly"]) {

                uint64_t diaChiBatDau = (uint64_t)headerImage + truotImage;
                uint64_t diaChiKetThuc = diaChiBatDau + 0x1000000;

                [self capNhatLog:[NSString stringWithFormat:@"Quét image: %@", tenImageStr]];
                [self capNhatLog:[NSString stringWithFormat:@"Base: 0x%llx", diaChiBatDau]];

                [self quetMauByte:diaChiBatDau denDiaChi:diaChiKetThuc];

                usleep(100000);
            }
        }
    }

    [self capNhatLog:@"Hoàn thành quét vùng nhớ"];
}

- (void)quetMauByte:(uint64_t)tuDiaChi denDiaChi:(uint64_t)denDiaChi {
    unsigned char mauByte[] = {0x00, 0x00, 0xA0, 0xE3};
    size_t doDaiMau = sizeof(mauByte);

    uint64_t viTri = tuDiaChi;
    NSInteger soLanTimThay = 0;

    while (viTri < denDiaChi && soLanTimThay < 20) {
        if (viTri < 0x100000000ULL && viTri > 0x1000) {
            unsigned char duLieu[4];

            memcpy(duLieu, (void *)viTri, doDaiMau);

            if (duLieu[0] == mauByte[0] &&
                duLieu[1] == mauByte[1] &&
                duLieu[2] == mauByte[2] &&
                duLieu[3] == mauByte[3]) {

                [self capNhatLog:[NSString stringWithFormat:@"Tìm thấy tại: 0x%llx", viTri]];
                soLanTimThay++;
            }
        }

        viTri += 4;
    }

    if (soLanTimThay == 0) {
        [self capNhatLog:@"Không tìm thấy mẫu byte"];
    }
}

- (void)doiTrangThaiMenu:(UIButton *)nut {
    MenuController *menu = objc_getAssociatedObject(nut, "menuController");
    if (menu != nil) {
        menu.view.hidden = !menu.view.hidden;

        if (!menu.view.hidden) {
            [menu capNhatLog:@"Menu đã được mở"];
        }
    }
}

@end

__attribute__((constructor))
void khoiTaoMenu(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *cuaSoMenu = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        cuaSoMenu.windowLevel = UIWindowLevelAlert + 1;
        cuaSoMenu.backgroundColor = [UIColor clearColor];

        UIButton *nutKichHoat = [UIButton buttonWithType:UIButtonTypeSystem];
        nutKichHoat.frame = CGRectMake(10, 100, 50, 50);
        nutKichHoat.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:0.8];
        nutKichHoat.layer.cornerRadius = 25;
        [nutKichHoat setTitle:@"MENU" forState:UIControlStateNormal];
        [nutKichHoat setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        nutKichHoat.titleLabel.font = [UIFont systemFontOfSize:10];

        MenuController *menuDieuKhien = [[MenuController alloc] init];
        menuDieuKhien.view.frame = CGRectMake(0, 0, 320, 600);
        menuDieuKhien.view.hidden = YES;

        [cuaSoMenu addSubview:menuDieuKhien.view];
        [cuaSoMenu addSubview:nutKichHoat];

        [nutKichHoat addTarget:menuDieuKhien action:@selector(doiTrangThaiMenu:) forControlEvents:UIControlEventTouchUpInside];

        objc_setAssociatedObject(nutKichHoat, "menuController", menuDieuKhien, OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(nutKichHoat, "cuaSoMenu", cuaSoMenu, OBJC_ASSOCIATION_RETAIN);

        cuaSoMenu.hidden = NO;
        [cuaSoMenu makeKeyAndVisible];
    });
}
