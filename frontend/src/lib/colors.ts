export function suggestColor(taken: string[]) {
  const used = new Set(taken.map((color) => color.toLowerCase()))
  for (let step = 0; step < 360; step += 1) {
    const color = hslHex((220 + step * 47) % 360, 52, 46)
    if (!used.has(color)) return color
  }
  return '#5c6bc0'
}

function hslHex(hue: number, saturation: number, lightness: number) {
  const chroma = (1 - Math.abs(2 * (lightness / 100) - 1)) * (saturation / 100)
  const sector = hue / 60
  const mix = chroma * (1 - Math.abs((sector % 2) - 1))
  const shift = lightness / 100 - chroma / 2
  const channel = sectorFloor(sector)
  const [red, green, blue] =
    channel === 0
      ? [chroma, mix, 0]
      : channel === 1
        ? [mix, chroma, 0]
        : channel === 2
          ? [0, chroma, mix]
          : channel === 3
            ? [0, mix, chroma]
            : channel === 4
              ? [mix, 0, chroma]
              : [chroma, 0, mix]
  return `#${byte(red + shift)}${byte(green + shift)}${byte(blue + shift)}`
}

function sectorFloor(sector: number) {
  return Math.floor(sector)
}

function byte(channel: number) {
  return Math.round(channel * 255)
    .toString(16)
    .padStart(2, '0')
}
