export const COLOR_PALETTE = [
  "#f3abab", // 2026 - pink
  "#f8bbd0", // 2027 - light pink
  "#d4a3dc", // 2028 - purple
  "#e1bee7", // 2029 - light purple
  "#7ec4f8", // 2030 - blue
  "#bbdefb", // 2031 - light blue
  "#6bc4ba", // 2032 - teal
  "#b2dfdb", // 2033 - light teal
  "#96d098", // 2034 - green
  "#c8e6c9", // 2035 - light green
  "#ffe066", // 2036 - yellow
  "#fff9c4", // 2037 - light yellow
  "#ffc570", // 2038 - orange
  "#ffe0b2", // 2039 - light orange
  "#f8a0bc", // 2040 - pink
];

export function getYearColor(year: string): string {
  const yearNum = parseInt(year, 10);
  if (isNaN(yearNum)) return "#ffffff";
  const index = ((yearNum - 2026) % COLOR_PALETTE.length + COLOR_PALETTE.length) % COLOR_PALETTE.length;
  return COLOR_PALETTE[index];
}
