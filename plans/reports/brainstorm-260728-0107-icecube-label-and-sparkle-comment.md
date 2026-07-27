# Brainstorm — "Ice Cube" label & Sparkle Info.plist comment

Date: 2026-07-28 | Branch: `main` | Mode: brainstorm only, no plan

---

## Item 1 — "Ice Cube" trong icon picker

### Contract

- **Outcome:** Settings → General → Frost icon không còn hiển thị chuỗi gợi upstream "Ice", mà không reset lựa chọn icon của người dùng đang chạy.
- **Constraints:** `Name.rawValue` vừa là display string vừa là khóa persist trong `Codable`; asset catalog `IceCube*` còn được tham chiếu ở 2 chỗ ngoài picker; repo có sẵn pattern migration (`MigrationManager`).
- **Non-goals:** thiết kế lại icon art, đổi tên asset catalog, đụng các `Name` case khác.
- **Acceptance:** picker hiện label mới; app đang cài (đã chọn Ice Cube) sau update vẫn giữ đúng icon; không có decode error trong log.

### Evidence

| Fact | Nguồn |
|---|---|
| `case iceCube = "Ice Cube"` | `Frost/MenuBar/ControlItem/ControlItemImageSet.swift:16` |
| rawValue được dùng trực tiếp làm label picker | `Frost/Settings/SettingsPanes/GeneralSettingsPane.swift:94` — `Text(imageSet.name.rawValue)` |
| rawValue cũng là dữ liệu persist: blob JSON dưới Defaults key `FrostIcon` | `Defaults.swift:144`; encode tại `GeneralSettingsManager.swift:136-142` |
| Decode fail → chỉ log, `frostIcon` giữ nguyên `.defaultFrostIcon` (= `.dot`) | `GeneralSettingsManager.swift:105-114`, `ControlItemImageSet.swift:40-44` |
| Blob persist **còn chứa cả** `.catalog("IceCubeStroke")` / `.catalog("IceCubeFill")` | `ControlItemImageSet.swift:74-77` |
| `.catalog(name)` không tìm thấy asset → `NSImage(named:)` trả `nil`, **không throw** | `ControlItemImage.swift` case `.catalog` |
| Asset `IceCubeStroke` còn dùng ở tab About và search panel | `SettingsView.swift:105`, `MenuBarSearchPanel.swift:360` |
| Có sẵn house pattern migration versioned + `hasMigrated…` guard + `deprecatedRawValue` | `Frost/Utilities/MigrationManager.swift:19-45, 393-400` |
| Đổi bundle id ở 1.0.0 → settings build cũ **không** carry over | `CHANGELOG.md` mục `[1.0.0] > Upgrade notes` |

### Hai failure mode, khác nhau về độ nguy hiểm

1. **Đổi `rawValue` mà không migrate** → decode throw → im lặng rơi về Dot. Người dùng mất lựa chọn, chỉ thấy log. Xấu nhưng nhìn ra được.
2. **Đổi tên asset (`IceCubeStroke`→…) mà không migrate** → *không* throw, `nsImage` = `nil` → icon menu bar **trống**, không log gì. Đây mới là mode nguy hiểm hơn, và nó nằm ở follow-up icon-design chứ không phải ở item này. Ghi nhận để phase icon design không dẫm phải.

### Blast radius thực tế

Rất nhỏ. Bundle id đổi ở 1.0.0 (release hôm nay) đã xoá sạch settings cũ. Blob `FrostIcon` chỉ tồn tại với ai đã chạy ≥1.0.0 **và** đổi icon khỏi mặc định Dot. Thực tế ≈ chính maintainer. Điều này không xoá bỏ nhu cầu migrate, nhưng nó loại option "migration nặng" khỏi bàn cân.

### Câu hỏi khung, phải chốt trước khi chọn giải pháp

Art hiện tại **đúng là một viên đá lạnh**. Nên chuỗi "Ice Cube" là mô tả chính xác của hình, không phải branding sót. Vấn đề chỉ là nó đọc lên gợi upstream Ice. Từ đó tách hai đường:

- **Đường cosmetic:** giữ art, đổi label thành trung tính ("Cube" / "Block").
- **Đường thực chất:** đây là việc icon design — thay art + đổi case + đổi asset. Rebrand plan phase-02 đã cố ý hoãn `IceCube` sang follow-up icon design (`plans/260727-2348-rebrand-ice-vc-to-frost/phase-02-…:50,68`).

### Options

**A. Tách display name khỏi rawValue** — thêm `var displayName: String` trên `Name`, dùng ở `GeneralSettingsPane.swift:94`. `rawValue` giữ nguyên `"Ice Cube"`.
- Chi phí: ~10 dòng, 2 file. Migration: **không cần**.
- Được: rủi ro bằng 0; và việc tách coupling này *dù sao cũng phải làm* trước bất kỳ lần đổi tên hiển thị nào sau này.
- Mất: chuỗi `"Ice Cube"` vẫn nằm trong blob defaults (người dùng không thấy).

**B. Đổi rawValue + custom `init(from decoder:)` trên `Name`** map legacy `"Ice Cube"` → case mới.
- Chi phí: ~15 dòng, cục bộ trong `ControlItemImageSet.swift`. Không cần đụng `MigrationManager`, không cần `hasMigrated` key, không có vấn đề thứ tự chạy.
- Được: blob sạch dần, tương thích ngược vĩnh viễn.
- Mất: thêm Codable thủ công cho enum; vẫn không giải quyết coupling display/persist (label vẫn = rawValue, lần đổi tên sau lại lặp lại y hệt).

**C. Entry trong `MigrationManager`** (`migrate1_x_y`) đọc blob, re-encode với tên mới.
- Chi phí: cao nhất. Cần `hasMigrated` key mới, và phải chắc chắn chạy **trước** khi `GeneralSettingsManager` load — rủi ro thứ tự.
- Chỉ đáng nếu cùng lúc phải viết lại cả `.catalog(...)` names (tức là khi đổi asset ở phase icon design).

**D. Bỏ hẳn case `iceCube`** khỏi `userSelectableFrostIcons`.
- Người đang chọn nó rơi về Dot — chính là failure mode 1, chỉ khác là cố ý.
- Chỉ hợp lý nếu art bị thay, tức thuộc phase icon design.

### Recommend

**Option A ngay bây giờ**, và hoãn việc đổi `rawValue` sang phase icon design để gộp làm một lần (khi đó dùng C, vì lúc đó bắt buộc phải viết lại cả tên asset trong blob — và đó mới là lúc migration có giá trị thật).

Lý do: A giải quyết đúng triệu chứng user thấy (chuỗi trong UI) với rủi ro 0; nó không phải công sức bỏ đi vì tách coupling là tiền đề cho mọi lần đổi tên sau; và nó tránh bắt người dùng nuốt **hai** lần migration cho cùng một icon.

Trade-off phải nói thẳng: A để lại label/art lệch nhau nếu chọn tên trung tính ("Cube" cho một viên đá lạnh). Nếu thấy lệch đó khó chấp nhận thì item này không phải việc đổi chuỗi — nó là việc icon design, và nên hoãn nguyên khối.

---

## Item 2 — Comment giải thích `SUEnableAutomaticChecks` trong Info.plist

### Contract

- **Outcome:** người đọc `Frost/Info.plist` hiểu được vì sao `SUEnableAutomaticChecks` = true mà không phải đi tra chỗ khác.
- **Constraints:** file là plist XML checked-in, build settings `GENERATE_INFOPLIST_FILE = YES` + `INFOPLIST_FILE = Frost/Info.plist` (`project.pbxproj:318-319, 350-351`) → Xcode merge lúc build.
- **Non-goals:** đổi giá trị Sparkle keys; tái cấu trúc docs.
- **Acceptance:** comment tồn tại trong source; build vẫn pass; giá trị runtime không đổi.

### Evidence

- `Frost/Info.plist` chỉ có 3 key Sparkle, không comment nào.
- Lý do **đã** được ghi ở hai nơi: `CHANGELOG.md:20` (mục `[1.0.1] > Fixed`) và `docs/UPSTREAM.md:26` (liệt kê điểm diverge khỏi upstream).
- Build ra plist nhị phân mới → comment không bao giờ ship, thuần túy là source-level.

### Rủi ro duy nhất, và nó có thật

Comment XML sống được trong file source, **nhưng** Xcode's Property List GUI editor rewrite file khi save và **xoá sạch comment**. `Info.plist` là file người ta hay lỡ mở bằng GUI editor. Nghĩa là comment ở đây là documentation *dễ bay hơi* — nó có thể biến mất im lặng trong một commit không liên quan.

### Options

**A. Không làm gì.** Lý do đã có ở CHANGELOG + UPSTREAM.md.
- Được: không có gì để rụng.
- Mất: người đọc plist trực tiếp (hoặc agent grep vào file) không thấy context.

**B. Thêm comment XML ngay trên key.** 1-2 dòng, trỏ về `docs/UPSTREAM.md`.
- Được: context tại chỗ, rẻ nhất.
- Mất: có thể bị GUI editor xoá âm thầm.

**C. Comment + một dòng ở `docs/UPSTREAM.md` ghi rõ "comment này dễ bị Xcode plist editor xoá; sửa file này ở dạng source".**
- Được: tự phòng thủ trước failure mode ở B.
- Mất: thêm chữ vào doc cho một chi tiết nhỏ.

### Recommend

**Option B**, comment ngắn, không lặp lại toàn bộ lý do — chỉ nêu ràng buộc và trỏ về nguồn đầy đủ. Ví dụ ý tứ: *accessory app không đưa được dialog xin phép của Sparkle lên trước, nên bật sẵn để bỏ prompt; chi tiết ở `docs/UPSTREAM.md`.*

Không recommend C: cảnh báo về Xcode plist editor là kiến thức chung về tooling, nhét vào UPSTREAM.md làm loãng một doc đang có mục đích rõ (theo dõi diverge khỏi upstream). Nếu comment có bị xoá thật thì nguồn chính (CHANGELOG + UPSTREAM.md) vẫn còn nguyên — thiệt hại giới hạn.

Cân nhắc quy mô: item này là 2 dòng, gần như không có design surface. Nếu muốn gộp, nó đi kèm được bất kỳ PR nào chạm Info.plist — không cần PR riêng.

---

## Tổng hợp hướng đề xuất

| Item | Hướng | Quy mô | Migration |
|---|---|---|---|
| 1 | Tách `displayName` khỏi `rawValue`, đổi label hiển thị; hoãn đổi `rawValue`+asset sang phase icon design | 2 file, ~10 dòng | Không |
| 2 | Comment XML ngắn trên `SUEnableAutomaticChecks` trỏ về `docs/UPSTREAM.md` | 1 file, 2 dòng | Không |

Cả hai đều không cần migration → có thể đi chung một PR nhỏ nếu muốn.

**Ghi lại cho phase icon design (đừng để mất):** khi đổi tên asset `IceCube*`, blob `FrostIcon` đã persist còn chứa `.catalog("IceCubeStroke")`. Asset thiếu **không throw** → icon menu bar trống, không log. Phase đó bắt buộc phải có migration re-encode blob, và phải xử lý cả `SettingsView.swift:105` + `MenuBarSearchPanel.swift:360`.

---

## Unresolved questions

1. **Item 1 — label mới là gì?** "Cube", "Block", hay giữ "Ice Cube"? Nếu chưa quyết được vì art vẫn là viên đá lạnh, thì câu hỏi thật là câu 2.
2. **Item 1 — có thay art không?** Nếu có, item này nên hoãn nguyên khối sang phase icon design thay vì đổi label trước rồi đổi lại sau.
3. **Item 1 — chuỗi `"Ice Cube"` còn nằm trong defaults blob có chấp nhận được không?** Nó user-invisible. Nếu yêu cầu là "sạch cả dữ liệu persist" thì Option A không đủ, phải là B.
4. **Item 2 — comment cho cả 3 key Sparkle hay chỉ `SUEnableAutomaticChecks`?** `SUFeedURL` và `SUPublicEDKey` cũng là điểm diverge khỏi upstream, nhưng chúng self-explanatory hơn.
5. Có gộp cả 2 item vào một PR không, hay tách theo `docs/DEVELOPMENT_WORKFLOW.md`?

---

# Addendum — sau khi user chốt (2026-07-28 01:12)

## Quyết định của user

1. Đổi label — cần gợi ý.
2. **Thay art luôn.**
3. Không chấp nhận để sót `"Ice Cube"` trong blob → **dọn sạch**.
4. Comment cho **cả 3** key Sparkle.
5. **Gộp 1 PR.**

## Phát hiện làm đổi khung của quyết định 2

`Frost/Assets.xcassets/AppIcon.appiconset/icon_256x256.png` **vẫn là logo cube xanh của Ice** — app icon chưa hề được rebrand (git log toàn bộ `Assets.xcassets` chỉ có 1 commit: rename project, không đụng art).

`IceCubeStroke` chính là bản đơn sắc của app icon đó. Nó **không phải một lựa chọn icon bình thường** — nó đang đóng vai *mark của app*:

| Chỗ dùng | Vai trò |
|---|---|
| `ControlItemImageSet.swift:74-77` | mục thứ 6 trong picker (lựa chọn thật) |
| `SettingsView.swift:105` — `case .about: .assetCatalog(.iceCubeStroke)` | **logo app** ở tab About |
| `MenuBarSearchPanel.swift:360` — `Image(.iceCubeStroke)` | **logo app** trong search panel |

→ "Thay art" tách thành **hai việc độc lập** đang dùng chung một asset:

- **(i) Mục chọn trong picker.** Chỉ cần một hình bất kỳ hợp bộ. Giải được bằng SF Symbol → xoá luôn asset, 0 file PNG phải vẽ.
- **(ii) Mark của app.** AppIcon (10 PNG) + template mono cho About/search. Đây là design deliverable thật, không phải code change.

Tin tốt: (i) làm được ngay trong PR này. (ii) độc lập, và nó là việc lẽ ra phải làm từ rebrand — hiện app vẫn mang logo Ice ở Dock, Finder, About, search panel.

## Gợi ý label

Convention của list là **tên hình thuần**, một từ: Arrow, Chevron, Door, Dot, Ellipsis, Sunglasses, Custom. Không có tên brand. Nên label = tên của hình mới, và vì thế **label phụ thuộc art** — không chọn label trước được.

Symbol availability đã verify trên máy này (`CoreGlyphs.bundle/symbol_order.plist`); cả hai bộ dưới đây đều thuộc SF Symbols 1 → an toàn với deployment target macOS 14.

| Label | hidden / visible | Ghi chú |
|---|---|---|
| **Snowflake** ⭐ | `snowflake.circle.fill` / `snowflake.circle` | hợp tên Frost, không trùng chữ "Frost" |
| Cube | `cube.fill` / `cube` | giữ mô-típ khối, nhưng vẫn gợi logo cũ |
| Hexagon | `hexagon.fill` / `hexagon` | trung tính, hơi vô nghĩa |
| Diamond | `diamond.fill` / `diamond` | gần crystal/băng |

Lưu ý: `snowflake` trần **không có** biến thể `.fill` (nó là glyph nét). Cặp `.circle` / `.circle.fill` là cách duy nhất có đủ stroke+fill.

Hướng hidden=fill, visible=stroke khớp Dot (`DotFill`/`DotStroke`) và Sunglasses (`sunglasses.fill`/`sunglasses`). `IceCube` hiện đang **ngược** (hidden=Stroke, visible=Fill) — sửa luôn cho nhất quán.

### Recommend: **Snowflake**

- Hợp tên app mà không đụng chữ "Frost" — quan trọng vì pane đã có `Toggle("Show Frost icon")` và `FrostMenu("Frost icon")`; một mục tên "Frost" trong picker sẽ đọc rất lẫn.
- Dùng SF Symbol → **xoá được cả folder `Assets.xcassets/ControlItemImages/IceCube/`**, không còn PNG nào dính tên Ice. Đúng yêu cầu "dọn sạch" ở quyết định 3, mà không tốn công vẽ.
- Đổi từ `.catalog` sang `.symbol` cũng loại luôn failure mode nguy hiểm đã nêu ở phần trên (asset thiếu → icon trống, không log): symbol thiếu thì cũng nil, nhưng symbol này là API ổn định của hệ thống, không phải file trong repo có thể bị đổi tên.

Đánh đổi phải nói rõ: chọn hướng này thì "thay art" ở mục picker được giải quyết bằng cách **bỏ art**, không phải vẽ art mới. Nếu ý định là có một hình vẽ riêng của Frost trong picker thì phải vẽ PNG template 40×40 @2x alpha-only (khớp `Contents.json` hiện tại: chỉ điền slot 2x, `template-rendering-intent: template`) — và lúc đó nên vẽ chung một lượt với (ii).

## Migration — giờ là bắt buộc

Blob persist chứa **cả hai**: `name: "Ice Cube"` và `.catalog("IceCubeStroke")` / `.catalog("IceCubeFill")`. Đổi rawValue + bỏ asset → phải re-encode, không map tên là đủ.

Hình dạng đơn giản nhất: **không patch từng field**. Nếu blob decode ra name cũ (hoặc decode fail), thay nguyên khối bằng imageSet mới lấy từ `userSelectableFrostIcons`. Vì hidden/visible đổi cả kiểu case (`.catalog` → `.symbol`), patch từng field vừa dài vừa dễ sai.

Đặt ở đâu — hai lựa chọn, cần scout ở turn plan:

- **`MigrationManager`** theo house pattern (`migrate1_1_0` + `hasMigrated1_1_0` guard, giống `migrate0_10_1`/`migrate0_11_10` tại `MigrationManager.swift:24-33`). Đúng convention repo. **Rủi ro: thứ tự chạy** — phải chắc `migrateAll` chạy *trước* `GeneralSettingsManager.loadInitialState`. Chưa verify, là việc đầu tiên của turn plan.
- **Xử lý tại chỗ trong `GeneralSettingsManager.swift:105-114`** ngay sau decode. Không có rủi ro thứ tự, không cần `hasMigrated` key, nhưng lệch house pattern và code migration nằm lẫn trong settings manager.

Blast radius vẫn rất nhỏ (bundle id đổi ở 1.0.0 hôm nay đã xoá settings cũ), nhưng vì user yêu cầu dọn sạch nên migration phải có thật, không phải chỉ để tránh reset.

## Sparkle — comment cả 3 key

| Key | Nội dung comment |
|---|---|
| `SUEnableAutomaticChecks` | accessory app không đưa được dialog xin phép của Sparkle lên trước → bật sẵn để bỏ prompt |
| `SUFeedURL` | trỏ về releases của fork này, không phải upstream Ice |
| `SUPublicEDKey` | public key của fork; private key ở Keychain, quy trình ở `docs/release-guide.md` |

Mỗi key 1 dòng, trỏ nguồn đầy đủ thay vì chép lại. Rủi ro Xcode plist GUI editor xoá comment vẫn giữ nguyên như đã phân tích — chấp nhận, vì nguồn chính (CHANGELOG + UPSTREAM.md) còn nguyên.

## Gộp 1 PR — cảnh báo phạm vi

Lúc recommend gộp, cả hai item đều là 2-10 dòng. Giờ item 1 gồm: đổi case + rawValue + symbol, xoá asset folder, viết migration, sửa 1-2 call site. Vẫn gộp được — không xung đột file với Info.plist — nhưng PR không còn là PR nhỏ.

Đề xuất phạm vi PR này:

- ✅ picker entry → Snowflake (SF Symbol), xoá `IceCube/` asset
- ✅ migration cho blob `FrostIcon`
- ✅ comment 3 key Sparkle
- ✅ CHANGELOG `[Unreleased]`
- ❌ **(ii) app mark / AppIcon** — tách riêng, vì nó là design deliverable và sẽ chặn PR này chờ art

Nhưng nếu tách (ii) ra thì `SettingsView.swift:105` và `MenuBarSearchPanel.swift:360` vẫn tham chiếu `iceCubeStroke` → **không xoá được asset folder** → mâu thuẫn với "dọn sạch". Đây là xung đột thật giữa quyết định 3 và việc tách (ii). Ba cách thoát, phải chốt ở turn plan:

- **a.** Giữ asset `IceCube/` lại chỉ cho vai trò app mark, đổi tên folder + file thành `FrostMark*` (rename thuần, art giữ nguyên tạm). Dọn sạch được *tên*, art đổi sau ở (ii). ← nhẹ nhất
- **b.** Kéo (ii) vào PR này luôn → PR chờ art.
- **c.** Chấp nhận để tên `IceCube` sót ở 2 chỗ app-mark → mâu thuẫn quyết định 3.

Nghiêng về **a**: nó thoả "không còn chữ Ice trong repo" ngay, mà không bắt PR chờ thiết kế. Lưu ý (a) cũng cần migration nếu asset còn nằm trong blob nào — nhưng sau khi picker chuyển sang SF Symbol thì blob không còn trỏ tới catalog name nữa, nên rename an toàn.

## Version

Đổi icon là thay đổi user-visible + có migration → minor bump theo `docs/release-guide.md`. Không tự cắt tag; chờ user duyệt số version.

## Unresolved questions (addendum)

1. Chốt **Snowflake** hay muốn vẽ art riêng cho mục picker? Nếu vẽ riêng thì PR này phải chờ art.
2. Xung đột "dọn sạch" vs tách app mark: chọn **a**, **b**, hay **c**?
3. Migration đặt ở `MigrationManager` hay xử lý tại chỗ trong `GeneralSettingsManager`? (phụ thuộc kết quả verify thứ tự chạy — việc đầu tiên của turn plan)
4. Có làm luôn AppIcon mới trong đợt này không, hay để thành plan riêng?

---

# Addendum 2 — chốt hết (2026-07-28 01:18)

## Quyết định user

1. **Snowflake** — chốt.
4. AppIcon mới → **plan riêng**.
2 & 3 — user uỷ quyền quyết định.

## Q3 — migration đặt ở đâu: **`MigrationManager`**

Không còn là judgment call. Đã verify chuỗi gọi:

```
FrostApp.init()                                   FrostApp.swift:15
  └─ MigrationManager.migrateAll(appState:)       ← chạy ở đây

AppDelegate.applicationDidFinishLaunching         AppDelegate.swift:27
  └─ DispatchQueue.main.asyncAfter(+0.1s)         AppDelegate.swift:46
       └─ appState.performSetup()                 AppDelegate.swift:54
            └─ settingsManager.performSetup()     AppState.swift:187
                 └─ generalSettingsManager.performSetup()   SettingsManager.swift:34
                      └─ loadInitialState()       GeneralSettingsManager.swift:79
                           └─ decode blob FrostIcon          :105-114
```

`App.init()` chạy trước `applicationDidFinishLaunching`, và `performSetup` còn bị hoãn thêm 0.1s. Migration **luôn** xong trước khi decode. Rủi ro thứ tự — lý do duy nhất để cân nhắc xử lý tại chỗ — không tồn tại.

Bonus: nếu thiếu permission thì `performSetup()` không chạy (AppDelegate.swift:52-58), nhưng migration vẫn chạy ở `init`. Thứ tự đúng chiều: migration vô điều kiện, load có điều kiện.

→ Dùng house pattern: thêm block vào mảng `performAll` tại `MigrationManager.swift:23-26` (loại throwing, không cần Result), guard bằng key `hasMigrated…` mới trong `Defaults.swift`.

Hình dạng migration: **thay nguyên khối, không patch từng field.** Blob cũ có `name: "Ice Cube"` + `.catalog("IceCubeStroke")` + `.catalog("IceCubeFill")`; blob mới là `.symbol(...)` — khác cả kiểu case, nên patch field vừa dài vừa dễ sai. Đọc blob, nếu name là `"Ice Cube"` (hoặc decode fail) thì ghi đè bằng imageSet Snowflake lấy từ `userSelectableFrostIcons`.

Tên hàm theo convention repo là số version (`migrate0_8_0`, `migrate0_11_10`) → phụ thuộc version chốt cho release này. Chưa đặt tên cứng ở đây.

## Q2 — xung đột "dọn sạch" vs tách app mark: **chọn a**, có điều chỉnh

Quyết định 4 (AppIcon → plan riêng) khoá luôn việc tách (ii). Còn lại a vs c; **c trái với quyết định 3**, nên chọn **a**.

Nhưng khi soi lại thì a gọn hơn tôi mô tả lúc trước, vì hai chuyện:

**1. `IceCubeFill` thành orphan.** Sau khi picker chuyển sang SF Symbol, tham chiếu duy nhất tới nó (`ControlItemImageSet.swift:76`) biến mất. Grep xác nhận không còn chỗ nào khác → **xoá hẳn**, không rename.

**2. `IceCubeStroke` không còn là control item image.** Hai chỗ dùng còn lại (`SettingsView.swift:105` tab About, `MenuBarSearchPanel.swift:360`) đều là *logo app*. Nó không thuộc `ControlItemImages/` nữa. Root `Assets.xcassets` đã có tiền lệ imageset đứng lẻ (`Warning.imageset`).

→ Hình dạng cuối:

| Việc | Chi tiết |
|---|---|
| `ControlItemImages/IceCube/IceCubeStroke.imageset/` | → `Assets.xcassets/FrostMarkStroke.imageset/` (art giữ nguyên tạm) |
| `ControlItemImages/IceCube/IceCubeFill.imageset/` | **xoá** — orphan |
| `SettingsView.swift:105` | `.assetCatalog(.iceCubeStroke)` → `.frostMarkStroke` |
| `MenuBarSearchPanel.swift:360` | `Image(.iceCubeStroke)` → `Image(.frostMarkStroke)` |

Kết quả: folder `IceCube/` biến mất, không còn chuỗi "Ice" nào trong repo ngoài các tham chiếu upstream cố ý (`docs/UPSTREAM.md`, CHANGELOG lịch sử).

Hai call site dùng **generated asset symbols** (`Image(.iceCubeStroke)`), tên do Xcode sinh từ tên asset → đổi tên asset là đổi symbol. Sai tên = compile error, không phải runtime bug. Rẻ để bắt, chỉ cần build verify.

Không cần migration thứ hai cho lần rename này: sau migration Snowflake, blob `FrostIcon` chỉ chứa `.symbol(...)`, không còn trỏ tới catalog name nào.

### Đánh đổi phải nói thẳng

Sau PR này tên là `FrostMark` nhưng art vẫn là cube của Ice. Tên và hình lệch nhau trong khoảng thời gian chờ plan AppIcon.

Chấp nhận được vì: lệch đó **đã tồn tại sẵn** (app tên Frost, logo Ice ở Dock/Finder/About/search) — a không làm tệ hơn, chỉ chưa sửa. Và nó dọn đường cho plan AppIcon: lúc đó chỉ drop PNG mới vào folder đã đúng tên, không phải rename giữa lúc đang đổi art.

## Phạm vi PR chốt lại

- Picker: case `iceCube` → `snowflake`, rawValue `"Ice Cube"` → `"Snowflake"`, `.catalog` → `.symbol("snowflake.circle.fill")` / `.symbol("snowflake.circle")` (hidden=fill, visible=stroke — sửa luôn chiều bị ngược của IceCube)
- Migration blob `FrostIcon` trong `MigrationManager` + key `hasMigrated…` mới
- Asset: rename `IceCubeStroke` → `FrostMarkStroke` (lên root), xoá `IceCubeFill`, xoá folder `IceCube/`
- 2 call site app-mark
- Comment 3 key Sparkle trong `Frost/Info.plist`
- CHANGELOG `[Unreleased]`

Không trong PR này: AppIcon + art mới cho `FrostMarkStroke` → plan riêng.

Verify: build pass (compile error nếu sai symbol name), và kiểm tay — cài bản cũ, chọn Ice Cube, update, xác nhận icon thành Snowflake chứ không rơi về Dot.

## Unresolved questions

1. **Version cho release này** — cần để đặt tên `migrateX_Y_Z` + key `hasMigratedX_Y_Z` theo convention repo. Đổi icon user-visible + có migration → minor bump theo `docs/release-guide.md`, tức 1.1.0 từ 1.0.1. Cần bạn duyệt trước khi plan ghim con số vào tên hàm.
2. Tên asset `FrostMarkStroke` — ổn chưa, hay muốn tên khác (`AppMark`, `BrandMark`)? Đổi sau tốn thêm một lần rename + build.
