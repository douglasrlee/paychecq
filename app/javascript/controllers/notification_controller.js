import { Controller } from '@hotwired/stimulus';
import { enter, leave } from 'el-transition';

export default class extends Controller {
  static targets = [ 'notification' ];

  connect() {
    this.openWithAnimation();
    this.closeAfterDelay();
  }

  openWithAnimation() {
    enter(this.notificationTarget);
  }

  closeAfterDelay() {
    setTimeout(() => {
      leave(this.notificationTarget);
    }, 5000);
  }

  close() {
    leave(this.notificationTarget);
  }
}
