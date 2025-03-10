# Dark Mode Guidelines for Compliance Views

This document outlines the patterns to use when adding dark mode compatibility to compliance views. Follow these guidelines for all compliance views to maintain a consistent look and feel.

## General Principles

1. **Add dark mode classes to all color-related classes**
2. **Use appropriate color contrasts for dark mode**
3. **Ensure text remains readable in dark mode**
4. **Test all interactive elements in dark mode**

## Common UI Elements

### Backgrounds

```html
<!-- Card backgrounds -->
<div class="bg-white dark:bg-gray-800">...</div>

<!-- Secondary/accent backgrounds -->
<div class="bg-gray-50 dark:bg-gray-700">...</div>

<!-- Form field backgrounds -->
<input class="bg-white dark:bg-gray-700">
```

### Text

```html
<!-- Primary text -->
<p class="text-gray-900 dark:text-gray-100">...</p>

<!-- Secondary text -->
<p class="text-gray-700 dark:text-gray-300">...</p>

<!-- Tertiary/muted text -->
<p class="text-gray-500 dark:text-gray-400">...</p>
```

### Borders

```html
<!-- Primary borders -->
<div class="border border-gray-200 dark:border-gray-700">...</div>

<!-- Secondary borders -->
<div class="border border-gray-300 dark:border-gray-600">...</div>
```

### Form Inputs

```html
<input type="text" class="border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-300 focus:ring-indigo-500 focus:border-indigo-500 dark:focus:ring-indigo-400 dark:focus:border-indigo-400">
```

### Buttons

```html
<!-- Primary button -->
<button class="bg-indigo-600 dark:bg-indigo-700 hover:bg-indigo-700 dark:hover:bg-indigo-600 text-white focus:ring-indigo-500 dark:focus:ring-offset-gray-800">...</button>

<!-- Secondary button -->
<button class="bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-600">...</button>
```

### Status Colors

```html
<!-- Success -->
<div class="bg-green-100 dark:bg-green-900/50 text-green-800 dark:text-green-300">...</div>

<!-- Warning -->
<div class="bg-yellow-50 dark:bg-yellow-900/20 text-yellow-800 dark:text-yellow-300">...</div>

<!-- Error -->
<div class="bg-red-50 dark:bg-red-900/20 text-red-800 dark:text-red-300">...</div>

<!-- Info -->
<div class="bg-blue-50 dark:bg-blue-900/20 text-blue-800 dark:text-blue-300">...</div>
```

### Shadows

```html
<div class="shadow dark:shadow-gray-900/30">...</div>
```

### Tables

```html
<table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
  <thead class="bg-gray-50 dark:bg-gray-700">
    <tr>
      <th class="text-gray-500 dark:text-gray-400">...</th>
    </tr>
  </thead>
  <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
    <tr>
      <td class="text-gray-900 dark:text-gray-300">...</td>
    </tr>
  </tbody>
</table>
```

## Complex Components

### Charts and Visualizations

For charts and visualizations in dark mode:
- Use brighter colors in dark mode
- Ensure sufficient contrast between colors
- Add "dark:" variations to all color classes
- Use opacity carefully to maintain readability

### Alerts and Notifications

```html
<!-- Success alert -->
<div class="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 text-green-800 dark:text-green-300">...</div>

<!-- Warning alert -->
<div class="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 text-yellow-800 dark:text-yellow-300">...</div>

<!-- Error alert -->
<div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-800 dark:text-red-300">...</div>
```

### Modals and Dialogs

```html
<div class="bg-white dark:bg-gray-800 shadow-xl">
  <div class="border-b border-gray-200 dark:border-gray-700">
    <h3 class="text-gray-900 dark:text-gray-100">...</h3>
  </div>
  <div class="p-6">
    <!-- Modal content -->
  </div>
</div>
```

## Implementation Process

When updating views for dark mode compatibility:

1. First update backgrounds (bg-*) 
2. Then update text colors (text-*)
3. Then update borders (border-*)
4. Finally handle form elements and interactive components

Always test the result in both light and dark modes to ensure readability and proper contrast.

## Additional Resources

- Tailwind Dark Mode Documentation: https://tailwindcss.com/docs/dark-mode
- WebAIM Contrast Checker: https://webaim.org/resources/contrastchecker/