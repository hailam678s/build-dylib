// ============================================
// FILE: MenuDylib.m
// ============================================
// ĐÃ SỬA:
// 1. Hiển thị offset rõ ràng để copy được
// 2. Hỗ trợ màn hình ngang (iPhone Xs)
// 3. Menu tự động xoay theo hướng màn hình
// 4. Thêm nút copy offset

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <sys/stat.h>
#import <sys/mman.h>
#import <mach/mach.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreGraphics/CoreGraphics.h>

@interface MenuController : UIViewController

@property (nonatomic, strong) UIButton *nutBatTat;
@property (nonatomic, strong) UITextView *khungLog;
@property (nonatomic, strong) UILabel *nhanTrangThai;
@property (nonatomic, strong) UILabel *nhanBanQuyen;
@property (nonatomic, strong) UIButton *nutCopy;
@property (nonatomic, strong) UIPanGestureRecognizer *cuaChi;
@property (nonatomic, assign) BOOL dangChay;
@property (nonatomic, assign) CGPoint diemBatDau;
@property (nonatomic, strong) NSMutableString *duLieuOffset;

- (void)batTatAutoTimKiem;
- (void)capNhatLog:(NSString *)noiDung;
- (void)tienHanhTimKiemOffset;
- (void)quetMauByte:(uint64_t)tuDiaChi denDiaChi:(uint64_t)denDiaChi;
- (void)doiTrangThaiMenu:(UIButton *)nut;
- (void)xuLyKeo:(UIPanGestureRecognizer *)cuChi;
- (void)copyOffset;

@end

@implementation MenuController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.duLieuOffset = [NSMutableString string];

    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.colors = @[(id)[UIColor colorWithRed:0.1 green:0.1 blue:0.3 alpha:0.9].CGColor,
                        (id)[UIColor colorWithRed:0.3 green:0.1 blue:0.5 alpha:0.9].CGColor,
                        (id)[UIColor colorWithRed:0.5 green:0.1 blue:0.3 alpha:0.9].CGColor];
    gradient.startPoint = CGPointMake(0, 0);
    gradient.endPoint = CGPointMake(1, 1);
    [self.view.layer insertSublayer:gradient atIndex:0];
    
    self.view.layer.cornerRadius = 15;
    self.view.layer.borderWidth = 2;
    self.view.layer.borderColor = [UIColor cyanColor].CGColor;
    self.view.clipsToBounds = YES;

    self.nhanBanQuyen = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 300, 30)];
    self.nhanBanQuyen.text = @"© HAI LAM";
    self.nhanBanQuyen.textAlignment = NSTextAlignmentCenter;
    self.nhanBanQuyen.font = [UIFont boldSystemFontOfSize:18];
    [self.view addSubview:self.nhanBanQuyen];
    
    [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        static int mauIndex = 0;
        mauIndex = (mauIndex + 1) % 7;
        NSArray *mauRainbow = @[[UIColor redColor], [UIColor orangeColor], [UIColor yellowColor],
                                [UIColor greenColor], [UIColor cyanColor], [UIColor blueColor], [UIColor purpleColor]];
        self.nhanBanQuyen.textColor = mauRainbow[mauIndex];
    }];

    self.nhanTrangThai = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, 280, 30)];
    self.nhanTrangThai.text = @"Trạng thái: TẮT";
    self.nhanTrangThai.textColor = [UIColor whiteColor];
    self.nhanTrangThai.textAlignment = NSTextAlignmentCenter;
    self.nhanTrangThai.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:self.nhanTrangThai];

    self.nutBatTat = [UIButton buttonWithType:UIButtonTypeSystem];
    self.nutBatTat.frame = CGRectMake(20, 90, 180, 50);
    [self.nutBatTat setTitle:@"BẬT AUTO TÌM OFFSET" forState:UIControlStateNormal];
    [self.nutBatTat setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.nutBatTat.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
    self.nutBatTat.layer.cornerRadius = 10;
    [self.nutBatTat addTarget:self action:@selector(batTatAutoTimKiem) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.nutBatTat];

    self.nutCopy = [UIButton buttonWithType:UIButtonTypeSystem];
    self.nutCopy.frame = CGRectMake(210, 90, 90, 50);
    [self.nutCopy setTitle:@"COPY" forState:UIControlStateNormal];
    [self.nutCopy setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.nutCopy.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0];
    self.nutCopy.layer.cornerRadius = 10;
    [self.nutCopy addTarget:self action:@selector(copyOffset) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.nutCopy];

    self.khungLog = [[UITextView alloc] initWithFrame:CGRectMake(10, 150, 300, 430)];
    self.khungLog.backgroundColor = [UIColor blackColor];
    self.khungLog.textColor = [UIColor greenColor];
    self.khungLog.font = [UIFont fontWithName:@"Menlo" size:11];
    self.khungLog.editable = NO;
    self.khungLog.layer.cornerRadius = 5;
    [self.view addSubview:self.khungLog];

    self.cuaChi = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(xuLyKeo:)];
    [self.view addGestureRecognizer:self.cuaChi];
    self.diemBatDau = CGPointZero;

    self.dangChay = NO;
    [self capNhatLog:@"Menu đã sẵn sàng - © Hai Lam"];
    [self capNhatLog:@"Bấm BẬT để quét offset"];
}

- (void)copyOffset {
    if (self.duLieuOffset.length > 0) {
        UIPasteboard *bangNhom = [UIPasteboard generalPasteboard];
        bangNhom.string = self.duLieuOffset;
        [self capNhatLog:@"✔ Đã copy toàn bộ offset vào clipboard"];
    } else {
        [self capNhatLog:@"Chưa có offset để copy"];
    }
}

- (void)xuLyKeo:(UIPanGestureRecognizer *)cuChi {
    UIView *view = cuChi.view;
    
    if (cuChi.state == UIGestureRecognizerStateBegan) {
        self.diemBatDau = view.center;
    }
    
    if (cuChi.state == UIGestureRecognizerStateChanged) {
        CGPoint diemDich = [cuChi translationInView:view.superview];
        view.center = CGPointMake(self.diemBatDau.x + diemDich.x, self.diemBatDau.y + diemDich.y);
    }
    
    if (cuChi.state == UIGestureRecognizerStateEnded) {
        CGPoint tam = view.center;
        CGSize kichThuoc = view.superview.bounds.size;
        CGSize kichThuocMenu = view.bounds.size;
        
        if (tam.x < kichThuocMenu.width / 2) tam.x = kichThuocMenu.width / 2;
        if (tam.y < kichThuocMenu.height / 2) tam.y = kichThuocMenu.height / 2;
        if (tam.x > kichThuoc.width - kichThuocMenu.width / 2) tam.x = kichThuoc.width - kichThuocMenu.width / 2;
        if (tam.y > kichThuoc.height - kichThuocMenu.height / 2) tam.y = kichThuoc.height - kichThuocMenu.height / 2;
        
        view.center = tam;
    }
}

- (void)batTatAutoTimKiem {
    self.dangChay = !self.dangChay;

    if (self.dangChay) {
        self.nhanTrangThai.text = @"Trạng thái: ĐANG CHẠY";
        self.nhanTrangThai.textColor = [UIColor greenColor];
        [self.nutBatTat setTitle:@"TẮT AUTO TÌM OFFSET" forState:UIControlStateNormal];
        self.nutBatTat.backgroundColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.2 alpha:1.0];
        [self capNhatLog:@"Đã bật tự động tìm kiếm offset"];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self tienHanhTimKiemOffset];
        });
    } else {
        self.nhanTrangThai.text = @"Trạng thái: TẮT";
        self.nhanTrangThai.textColor = [UIColor whiteColor];
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
                [tenImageStr containsString:@"GameAssembly"] ||
                [tenImageStr containsString:@"Roblox"] ||
                [tenImageStr containsString:@"FreeFire"] ||
                [tenImageStr containsString:@"PUBG"]) {

                unsigned long kichThuocText = 0;
                uint8_t *batDauText = getsegmentdata((const struct mach_header_64 *)headerImage, "__TEXT", &kichThuocText);
                
                if (batDauText != NULL && kichThuocText > 0) {
                    uint64_t diaChiBatDau = (uint64_t)batDauText + truotImage;
                    uint64_t diaChiKetThuc = diaChiBatDau + kichThuocText;

                    [self capNhatLog:[NSString stringWithFormat:@"Quét image: %@", tenImageStr]];
                    [self capNhatLog:[NSString stringWithFormat:@"Base: 0x%llx", diaChiBatDau]];
                    [self capNhatLog:[NSString stringWithFormat:@"Kích thước __TEXT: %lu bytes", kichThuocText]];

                    [self quetMauByte:diaChiBatDau denDiaChi:diaChiKetThuc];
                } else {
                    [self capNhatLog:[NSString stringWithFormat:@"Không lấy được __TEXT segment: %@", tenImageStr]];
                }

                usleep(100000);
            }
        }
    }

    [self capNhatLog:@"Hoàn thành quét vùng nhớ"];
}

- (void)quetMauByte:(uint64_t)tuDiaChi denDiaChi:(uint64_t)denDiaChi {
    unsigned char mauByte1[] = {0xFD, 0x7B, 0xBF, 0xA9};
    unsigned char mauByte2[] = {0xFD, 0x03, 0x00, 0x91};
    unsigned char mauByte3[] = {0x08, 0x00, 0x40, 0xF9};
    unsigned char mauByte4[] = {0x00, 0x00, 0x80, 0xD2};
    unsigned char mauByte5[] = {0xC0, 0x03, 0x5F, 0xD6};

    uint64_t viTri = tuDiaChi;
    NSInteger soLanTimThay = 0;

    while (viTri < denDiaChi && soLanTimThay < 200) {
        if (viTri > 0x1000) {
            unsigned char duLieu[4];

            memcpy(duLieu, (void *)viTri, 4);

            if ((duLieu[0] == mauByte1[0] && duLieu[1] == mauByte1[1] && duLieu[2] == mauByte1[2] && duLieu[3] == mauByte1[3]) ||
                (duLieu[0] == mauByte2[0] && duLieu[1] == mauByte2[1] && duLieu[2] == mauByte2[2] && duLieu[3] == mauByte2[3]) ||
                (duLieu[0] == mauByte3[0] && duLieu[1] == mauByte3[1] && duLieu[2] == mauByte3[2] && duLieu[3] == mauByte3[3]) ||
                (duLieu[0] == mauByte4[0] && duLieu[1] == mauByte4[1] && duLieu[2] == mauByte4[2] && duLieu[3] == mauByte4[3]) ||
                (duLieu[0] == mauByte5[0] && duLieu[1] == mauByte5[1] && duLieu[2] == mauByte5[2] && duLieu[3] == mauByte5[3])) {

                NSString *offsetStr = [NSString stringWithFormat:@"0x%llx", viTri];
                [self capNhatLog:[NSString stringWithFormat:@"✔ Offset: %@", offsetStr]];
                [self.duLieuOffset appendFormat:@"%@\n", offsetStr];
                soLanTimThay++;
            }
        }

        viTri += 4;
    }

    if (soLanTimThay == 0) {
        [self capNhatLog:@"Không tìm thấy mẫu byte trong vùng này"];
    } else {
        [self capNhatLog:[NSString stringWithFormat:@"Tổng cộng: %ld offset tìm thấy", (long)soLanTimThay]];
        [self capNhatLog:@"Bấm nút COPY để copy tất cả offset"];
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

// Hỗ trợ xoay màn hình
- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end

__attribute__((constructor))
void khoiTaoMenu(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *cuaSoMenu = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        cuaSoMenu.windowLevel = UIWindowLevelAlert + 1;
        cuaSoMenu.backgroundColor = [UIColor clearColor];

        UIButton *nutKichHoat = [UIButton buttonWithType:UIButtonTypeSystem];
        nutKichHoat.frame = CGRectMake(10, 100, 60, 60);
        nutKichHoat.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:0.8];
        nutKichHoat.layer.cornerRadius = 30;
        [nutKichHoat setTitle:@"MENU" forState:UIControlStateNormal];
        [nutKichHoat setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        nutKichHoat.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        nutKichHoat.layer.borderWidth = 2;
        nutKichHoat.layer.borderColor = [UIColor cyanColor].CGColor;

        MenuController *menuDieuKhien = [[MenuController alloc] init];
        
        // Tự điều chỉnh kích thước theo màn hình
        CGFloat chieuRong = [UIScreen mainScreen].bounds.size.width;
        CGFloat chieuCao = [UIScreen mainScreen].bounds.size.height;
        
        // Nếu màn hình ngang, đổi kích thước menu
        if (chieuRong > chieuCao) {
            menuDieuKhien.view.frame = CGRectMake(20, 80, 350, 350);
        } else {
            menuDieuKhien.view.frame = CGRectMake(20, 180, 320, 600);
        }
        
        menuDieuKhien.view.hidden = YES;

        [cuaSoMenu addSubview:menuDieuKhien.view];
        [cuaSoMenu addSubview:nutKichHoat];

        [nutKichHoat addTarget:menuDieuKhien action:@selector(doiTrangThaiMenu:) forControlEvents:UIControlEventTouchUpInside];

        objc_setAssociatedObject(nutKichHoat, "menuController", menuDieuKhien, OBJC_ASSOCIATION_RETAIN);
        objc_setAssociatedObject(nutKichHoat, "cuaSoMenu", cuaSoMenu, OBJC_ASSOCIATION_RETAIN);

        cuaSoMenu.hidden = NO;
        [cuaSoMenu makeKeyAndVisible];
        
        // Lắng nghe sự kiện xoay màn hình
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            CGFloat chieuRongMoi = [UIScreen mainScreen].bounds.size.width;
            CGFloat chieuCaoMoi = [UIScreen mainScreen].bounds.size.height;
            
            if (chieuRongMoi > chieuCaoMoi) {
                menuDieuKhien.view.frame = CGRectMake(20, 80, 350, 350);
            } else {
                menuDieuKhien.view.frame = CGRectMake(20, 180, 320, 600);
            }
        }];
    });
}
