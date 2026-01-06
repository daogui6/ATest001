import router from '@ohos.router';

@Entry
@Component
struct SplashPage {
  private navigateTimer?: number;
  @State iconOpacity: number = 0.6;
  @State iconScale: number = 0.9;

  aboutToAppear() {
    animateTo({ duration: 800, curve: Curve.EaseOut }, () => {
      this.iconOpacity = 1;
      this.iconScale = 1;
    });

    this.navigateTimer = setTimeout(() => {
      router.replaceUrl({ url: 'pages/Index' });
    }, 1800);
  }

  aboutToDisappear() {
    if (this.navigateTimer !== undefined) {
      clearTimeout(this.navigateTimer);
      this.navigateTimer = undefined;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image($r('app.media.background'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      Column({ space: 16 }) {
        Image($r('app.media.startIcon'))
          .width(140)
          .height(140)
          .objectFit(ImageFit.Contain)
          .opacity(this.iconOpacity)
          .scale({ x: this.iconScale, y: this.iconScale })
          .borderRadius(28)

        Text('加载中...')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .opacity(this.iconOpacity)
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FF')
  }
}