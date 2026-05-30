# 01 - Design System

## Màu chính

| Token | Giá trị | Dùng cho |
| --- | --- | --- |
| `primary` | `#2563EB` | Button chính, icon page, active nav |
| `primaryHover` | `#1D4ED8` | Hover/pressed primary |
| `primarySoft` | `#EAF1FF` | Active nav, soft icon background |
| `primaryBorder` | `#BFD2FF` | Border element active |
| `zaloBlue` | `#0068FF` | Preview Zalo, accent đặc thù |

## Màu phụ

| Token | Giá trị |
| --- | --- |
| `purpleSoft` | `#F1E8FF` |
| `amberSoft` | `#FFF4D6` |
| `greenSoft` | `#DFF8EE` |
| `cyanSoft` | `#E8F7FF` |
| `slateSoft` | `#F1F5F9` |

## Nền, border, text

| Token | Giá trị | Ghi chú |
| --- | --- | --- |
| `appBackground` | `#F6F9FD` | Nền content |
| `surface` | `#FFFFFF` | Card/sidebar/topbar |
| `surfaceMuted` | `#F8FAFC` | Empty/table stripe nhẹ |
| `border` | `#DBE3EF` | Border chính |
| `borderSoft` | `#E7EDF5` | Divider |
| `textPrimary` | `#0F172A` | Tiêu đề |
| `textSecondary` | `#475569` | Body |
| `textMuted` | `#718096` | Subtitle, placeholder |
| `iconMuted` | `#64748B` | Empty icons |

## Màu trạng thái

| Status | Main | Soft | Text |
| --- | --- | --- | --- |
| Success | `#10B981` | `#DFF8EE` | `#047857` |
| Warning | `#F59E0B` | `#FFF4D6` | `#B45309` |
| Error | `#EF4444` | `#FDE8E8` | `#DC2626` |
| Info | `#2563EB` | `#EAF6FF` | `#1D4ED8` |
| Disabled | `#CBD5E1` | `#F1F5F9` | `#94A3B8` |

## Typography

- Font ưu tiên: `Inter` qua `google_fonts`. Fallback: `Roboto`, `Arial`, sans-serif.
- `pageTitle`: 26px, weight 700, line-height 32px.
- `sectionTitle`: 16px, weight 700, line-height 22px.
- `cardTitle`: 15px, weight 700, line-height 20px.
- `body`: 14px, weight 400-500, line-height 20px.
- `label`: 13px, weight 600, line-height 18px.
- `caption`: 12px, weight 500, line-height 16px.
- Không scale font theo viewport width. Trên mobile chỉ giảm spacing/layout, không giảm chữ quá mức.

## Radius, shadow, spacing

- Radius: `4px` cho chip/input nhỏ, `6px` cho button, `8px` cho card/panel, `999px` cho pill/badge.
- Shadow: dùng rất nhẹ: `0 1px 2px rgba(15, 23, 42, 0.04)` hoặc không dùng nếu đã có border.
- Spacing scale: `4, 8, 12, 16, 20, 24, 32, 40, 48`.
- Card padding desktop: `24px`. Form panel padding: `16-20px`. Toolbar gap: `8-12px`.

## Kích thước layout

- Sidebar desktop: `250px`.
- Sidebar collapsed tablet: `72px`.
- Top breadcrumb/header bar: `64px`.
- Page header block: `88-96px`.
- Content horizontal padding desktop: `32px`, tablet: `24px`, mobile: `16px`.
- Button height: `38-40px`.
- Input/select height: `38-40px`.
- Metric card height: `76px`.
- Empty state icon: `40-64px`, text max width `420px`.

## Quy tắc card

- Card nền trắng, border `border`, radius `8px`.
- Không lồng card trang trí trong card. Chỉ lồng panel khi đó là form group/accordion rõ ràng.
- Header card dùng title 15-16px, divider nếu có nhiều field.
- Empty card giữ chiều cao tối thiểu để giống ảnh: list/table khoảng `180-320px`, workspace lớn có thể `calc(100vh - header)`.

## Quy tắc table

- Dùng `data_table_2` hoặc custom table wrapper.
- Header nền trắng hoặc `surfaceMuted`, text label 12-13px weight 700.
- Row height `48px`.
- Phải có states: loading skeleton, empty state, error state, selected row.

## Quy tắc form

- Label trên input, font 13px weight 600.
- Placeholder màu `textMuted`.
- Form controls border `border`, focused border `primary`.
- Numeric fields cùng hàng trên desktop, stack trên mobile.
- Alert validation/error dùng nền soft error và icon line.

## Quy tắc button

- Primary: nền `primary`, text trắng, icon trái nếu có action rõ.
- Secondary/outline: nền trắng, border `border`, text `textSecondary`.
- Destructive: nền `#FDE8E8`, border `#FCA5A5`, text `#EF4444`.
- Disabled: nền `#CBD5E1`, text trắng hoặc `#94A3B8`, không hover.
- Icon button vuông `38x38`.

## Quy tắc responsive

- Desktop/web `>=1100px`: sidebar cố định, content rộng, các màn hình campaign dùng 2-3 cột như ảnh.
- Tablet `650-1099px`: sidebar collapsed hoặc drawer rail, content 1-2 cột; giữ breadcrumb và page header.
- Mobile `<650px`: drawer hoặc bottom navigation cho nhóm chính; form/panel stack một cột; toolbar chuyển wrap; table dùng horizontal scroll hoặc card rows.
- Các panel campaign trên mobile xếp thứ tự: target/config trước, preview/log sau.
- Không để text trong button overflow; button có thể xuống dòng hoặc dùng icon-only với tooltip.
