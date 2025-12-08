import type { ClassValue } from 'clsx'
import { clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function humanReadableByteSize(size: number, fractionDigits: number = 1): string {
  if (size < 1024) {
    return `${size} B`
  }

  if (size < 1024 ** 2) {
    return `${(size / 1024).toFixed(fractionDigits)} KB`
  }

  if (size < 1024 ** 3) {
    return `${(size / 1024 ** 2).toFixed(fractionDigits)} MB`
  }

  if (size < 1024 ** 4) {
    return `${(size / 1024 ** 3).toFixed(fractionDigits)} GB`
  }

  if (size < 1024 ** 5) {
    return `${(size / 1024 ** 4).toFixed(fractionDigits)} TB`
  }

  if (size < 1024 ** 6) {
    return `${(size / 1024 ** 5).toFixed(fractionDigits)} PB`
  }

  if (size < 1024 ** 7) {
    return `${(size / 1024 ** 6).toFixed(fractionDigits)} EB`
  }

  if (size < 1024 ** 8) {
    return `${(size / 1024 ** 7).toFixed(fractionDigits)} ZB`
  }

  return `${(size / 1024 ** 8).toFixed(fractionDigits)} YB`
}
