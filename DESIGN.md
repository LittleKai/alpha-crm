---
name: Alpha CRM Design System
description: Modern, reliable, and professional visual guidelines for Alpha CRM
colors:
  primary: "#2563EB"
  primary-hover: "#1D4ED8"
  primary-soft: "#EAF1FF"
  primary-border: "#BFD2FF"
  surface: "#FFFFFF"
  surface-muted: "#F8FAFC"
  app-background: "#F6F9FD"
  border: "#DBE3EF"
  border-soft: "#E7EDF5"
  text-primary: "#0F172A"
  text-secondary: "#475569"
  text-muted: "#718096"
  success: "#10B981"
  success-soft: "#DFF8EE"
  success-text: "#047857"
  warning: "#F59E0B"
  error: "#EF4444"
typography:
  display:
    fontFamily: "Be Vietnam Pro"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.2
  headline:
    fontFamily: "Be Vietnam Pro"
    fontSize: "18px"
    fontWeight: 700
    lineHeight: 1.33
  title:
    fontFamily: "Be Vietnam Pro"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.37
  body:
    fontFamily: "Be Vietnam Pro"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.46
  label:
    fontFamily: "Be Vietnam Pro"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: 1.42
rounded:
  xs: "4px"
  s: "6px"
  m: "8px"
  pill: "999px"
spacing:
  xs: "4px"
  s: "8px"
  sm: "12px"
  m: "16px"
  ml: "20px"
  l: "24px"
  xl: "32px"
  xxl: "40px"
  xxxl: "48px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#FFFFFF"
    rounded: "{rounded.m}"
    padding: "10px 20px"
  button-primary-hover:
    backgroundColor: "{colors.primary-hover}"
---

# Design System: Alpha CRM

## 1. Overview

**Creative North Star: "The Expert Workspace"**

Alpha CRM is designed to project expert confidence, high operational efficiency, and absolute reliability. It acts as an ambient workspace where marketing operations are performed with precision. Spacing is comfortable, layouts are responsive and highly readable, and the color palette is restrained to minimize cognitive fatigue.

We explicitly reject over-saturated gradients, unaligned spacing blocks, side-stripe borders, and glassmorphism.

**Key Characteristics:**
- **Visual Restraint**: High contrast, minimal colors, clear content hierarchy.
- **Responsive Fluidity**: Standard flex wraps and grids ensure zero layout overflow at all breakpoints.
- **Intentional Spacing**: Elements align strictly to an 8px base spacing grid.

## 2. Colors

The color palette is built on deep corporate blues, crisp off-whites, and highly readable status indicators.

### Primary
- **Active Blue** (#2563EB): Used for interactive controls, brand highlights, and main call-to-actions.
- **Deep Slate** (#0F172A): Primary typography color ensuring exceptional legibility.

### Neutral
- **App Canvas** (#F6F9FD): Restful light background that helps reduce eye strain.
- **Card Fill** (#FFFFFF): Pure white surface for content blocks.
- **Border Slate** (#DBE3EF): Soft boundary color that organizes grids without cluttering the screen.

**The Restraint Rule.** The primary accent color is used on ≤10% of any given screen. Its rarity is the point.

## 3. Typography

**Display Font**: Be Vietnam Pro
**Body Font**: Be Vietnam Pro

The typeface is selected for its superior Vietnamese character set rendering and crisp geometry in web/desktop environments.

### Hierarchy
- **Display** (700, 28px, 1.2): Main page headers and page titles.
- **Headline** (700, 18px, 1.33): Section headers and primary block titles.
- **Title** (700, 16px, 1.37): Card titles and details labels.
- **Body** (400, 15px, 1.46): Primary paragraphs, checklists, and descriptive texts. Line lengths capped at 75ch.
- **Label** (600, 14px, 1.42): Buttons, badges, and small metadata.

## 4. Elevation

The interface is predominantly flat. Visual depth is established using subtle, high-contrast borders and light background shading rather than heavy shadows.

### Shadow Vocabulary
- **Interactive Focus** (`box-shadow: 0 4px 12px rgba(37, 99, 235, 0.08)`): Soft glowing accent under the recommended subscription packages.

**The Flat-By-Default Rule.** Surfaces are flat at rest. Subtle borders define structural units.

## 5. Components

### Buttons
- **Shape**: Smooth curves (8px radius).
- **Primary**: Active Blue background, white text, 10px 20px padding.
- **Outline**: Thin Border Slate stroke, Active Blue text.

### Cards / Containers
- **Corner Style**: Rounded corners (8px radius).
- **Background**: Surface White (#FFFFFF) or Soft Muted Surface (#F8FAFC).
- **Border**: Thin Border Slate stroke (1px, #DBE3EF).
- **Internal Padding**: Medium (16px) or Large (24px).

### Progress Bars
- **Style**: Rounded track with a solid colored fill representing quota utilization. Track background uses Soft Neutral (#E7EDF5).

## 6. Do's and Don'ts

### Do:
- **Do** align all margins and paddings strictly to the `AppSpacing` values.
- **Do** wrap pricing metrics in `Wrap` elements to handle narrow viewport constraints cleanly.
- **Do** use `Be Vietnam Pro` or equivalent system typography with explicit line-height rules.

### Don't:
- **Don't** use colored `border-left` or `border-right` greater than 1px as decoration on cards.
- **Don't** combine text with linear gradient backgrounds.
- **Don't** use decorative glassmorphism or blur containers on dashboards.
- **Don't** allow text or buttons to overflow their boundaries on mobile viewport (390px).
