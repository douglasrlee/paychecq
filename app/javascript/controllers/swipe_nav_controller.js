import { Controller } from "@hotwired/stimulus";

const SWIPE_THRESHOLD = 80;        // Minimum px to commit navigation on release
const SNAP_DURATION = 200;         // Duration for snap-to / spring-back animation (ms)
const RESISTANCE = 0.3;            // Dampening when dragging past the edge (no adjacent page)

export default class extends Controller {
  static values = {
    paths: Array,   // Ordered page paths, e.g. ["/transactions", "/expenses", "/goals"]
    current: Number // Index of current page in paths array
  };

  connect() {
    this.startX = null;
    this.startY = 0;
    this.tracking = false;  // true once we've determined this is a horizontal gesture
    this.locked = false;    // true once we've determined this is a vertical gesture (scroll)
    this.swiping = false;   // true once navigation is committed

    this.boundOnTouchStart = this.onPointerStart.bind(this);
    this.boundOnTouchMove = this.onPointerMove.bind(this);
    this.boundOnTouchEnd = this.onPointerEnd.bind(this);

    this.element.addEventListener("touchstart", this.boundOnTouchStart, { passive: true });
    this.element.addEventListener("touchmove", this.boundOnTouchMove, { passive: false });
    this.element.addEventListener("touchend", this.boundOnTouchEnd, { passive: true });
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.boundOnTouchStart);
    this.element.removeEventListener("touchmove", this.boundOnTouchMove);
    this.element.removeEventListener("touchend", this.boundOnTouchEnd);
    this.resetTransform();
  }

  // --- Touch handlers ---

  onPointerStart(e) {
    if (this.swiping) return;
    this.startX = e.touches[0].clientX;
    this.startY = e.touches[0].clientY;
    this.tracking = false;
    this.locked = false;
    this.element.style.transition = "none";
  }

  onPointerMove(e) {
    if (this.swiping || this.locked || this.startX === null) return;

    const dx = e.touches[0].clientX - this.startX;
    const dy = e.touches[0].clientY - this.startY;

    // Determine gesture direction on first significant movement
    if (!this.tracking && (Math.abs(dx) > 10 || Math.abs(dy) > 10)) {
      if (Math.abs(dy) > Math.abs(dx)) {
        this.locked = true; // Vertical scroll — bail out
        return;
      }
      this.tracking = true;
    }

    if (this.tracking) {
      e.preventDefault(); // Prevent scroll while dragging horizontally
      this.applyTransform(dx);
    }
  }

  onPointerEnd(e) {
    if (this.swiping || this.locked || this.startX === null) { this.startX = null; return; }
    const dx = e.changedTouches[0].clientX - this.startX;
    this.resolve(dx);
  }

  // --- Shared logic ---

  // Apply real-time transform following the pointer
  applyTransform(dx) {
    const direction = dx < 0 ? 1 : -1;
    const targetIndex = this.currentValue + direction;
    const hasTarget = targetIndex >= 0 && targetIndex < this.pathsValue.length;

    // Apply resistance if no adjacent page in this direction
    const adjustedDx = hasTarget ? dx : dx * RESISTANCE;

    this.element.style.transform = `translateX(${adjustedDx}px)`;
    this.element.style.opacity = Math.max(1 - Math.abs(adjustedDx) / this.element.offsetWidth * 0.4, 0.6);
  }

  // On release: commit navigation or spring back
  resolve(dx) {
    this.startX = null;
    const direction = dx < 0 ? 1 : -1;
    const targetIndex = this.currentValue + direction;
    const hasTarget = targetIndex >= 0 && targetIndex < this.pathsValue.length;

    if (hasTarget && Math.abs(dx) >= SWIPE_THRESHOLD) {
      // Commit: animate out the rest of the way
      this.swiping = true;
      const targetPath = this.pathsValue[targetIndex];
      const slideInClass = direction > 0 ? "slide-in-right" : "slide-in-left";

      // Set up a one-shot before-render listener that survives controller disconnect
      document.addEventListener("turbo:before-render", (event) => {
        const newMain = event.detail.newBody.querySelector("main");
        if (newMain) newMain.classList.add(slideInClass);
      }, { once: true });

      this.element.style.transition = `transform ${SNAP_DURATION}ms ease-out, opacity ${SNAP_DURATION}ms ease-out`;
      this.element.style.transform = `translateX(${-direction * this.element.offsetWidth}px)`;
      this.element.style.opacity = "0";

      setTimeout(() => {
        Turbo.visit(targetPath, { action: "replace" });
      }, SNAP_DURATION);
    } else {
      // Spring back
      this.element.style.transition = `transform ${SNAP_DURATION}ms ease-out, opacity ${SNAP_DURATION}ms ease-out`;
      this.element.style.transform = "translateX(0)";
      this.element.style.opacity = "1";

      setTimeout(() => this.resetTransform(), SNAP_DURATION);
    }
  }

  resetTransform() {
    this.element.style.transition = "";
    this.element.style.transform = "";
    this.element.style.opacity = "";
  }
}
