export class DeltaMeter {
  private lastValue: number | null = null
  private lastTime: number | null = null
  private ema = 0
  private readonly smoothing: number
  private avgValue = 0
  private updateTimer: ReturnType<typeof setInterval> | null = null

  get avg() {
    return this.avgValue
  }

  constructor(
    private updateIntervalMs = 200,
    smoothing = 0.2,
  ) {
    this.smoothing = smoothing

    this.updateTimer = setInterval(() => this.updateAvg(), updateIntervalMs)
  }

  sample(value: number) {
    const now = performance.now()

    if (this.lastValue !== null && this.lastTime !== null) {
      const dv = value - this.lastValue
      const dt = (now - this.lastTime) / 1000
      if (dt > 0) {
        const dps = dv / dt
        this.ema = this.ema === 0 ? dps : this.ema * (1 - this.smoothing) + dps * this.smoothing
      }
    }

    this.lastValue = value
    this.lastTime = now
  }

  reset() {
    this.lastValue = null
    this.lastTime = null
    this.ema = 0
    this.avgValue = 0

    if (this.updateTimer === null) {
      this.updateTimer = setInterval(() => this.updateAvg(), this.updateIntervalMs)
    }
  }

  stop() {
    if (this.updateTimer !== null) {
      clearInterval(this.updateTimer)
    }
  }

  private updateAvg() {
    // decay EMA if no samples came since last update
    if (this.lastTime !== null) {
      const now = performance.now()
      const dt = now - this.lastTime
      if (dt > this.updateIntervalMs) {
        this.ema *= 1.0 - this.smoothing
      }
    }
    this.avgValue = this.ema
  }
}
