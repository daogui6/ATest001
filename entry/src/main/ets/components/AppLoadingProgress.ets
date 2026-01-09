/**
 * AppLoadingProgress.ets - 应用统一加载动画
 *
 * 功能说明：
 * - 使用学犀(app.media.xuexi)作为中心图标
 * - 使用胡萝卜(app.media.luobo)绕中心旋转
 * - 通过定时器驱动旋转动画
 */

@Component
export struct AppLoadingProgress {
  @State private orbitAngle: number = 0;

  @Prop iconSize: number = 28;
  @Prop orbitRadius: number = 14;
  @Prop orbitImageSize: number = 10;

  private orbitTimer?: number;
  private readonly orbitTickMs: number = 16;
  private readonly orbitSpeed: number = 3;

  aboutToAppear() {
    this.startOrbitAnimation();
  }

  aboutToDisappear() {
    if (this.orbitTimer !== undefined) {
      clearInterval(this.orbitTimer);
      this.orbitTimer = undefined;
    }
  }

  private startOrbitAnimation() {
    if (this.orbitTimer !== undefined) {
      clearInterval(this.orbitTimer);
    }
    this.orbitTimer = setInterval(() => {
      this.orbitAngle = (this.orbitAngle + this.orbitSpeed) % 360;
    }, this.orbitTickMs);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.xuexi'))
        .width(this.iconSize)
        .height(this.iconSize)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.iconSize / 2)

      Image($r('app.media.luobo'))
        .width(this.orbitImageSize)
        .height(this.orbitImageSize)
        .objectFit(ImageFit.Contain)
        .translate({
          x: this.orbitRadius * Math.cos(this.orbitAngle * Math.PI / 180),
          y: this.orbitRadius * Math.sin(this.orbitAngle * Math.PI / 180)
        })
    }
    .width(this.iconSize + this.orbitRadius * 2)
    .height(this.iconSize + this.orbitRadius * 2)
  }
}