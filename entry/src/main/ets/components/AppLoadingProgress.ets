/**
 * AppLoadingProgress.ets - 应用统一加载动画
 *
 * 功能说明：
 * - 使用学习(app.media.xuexi)作为中心图标
 * - 使用胡萝卜(app.media.luobo)绕中心旋转
 * - 通过定时器驱动旋转动画
 */

@Component
export struct AppLoadingProgress {
  @State private orbitAngle: number = 0; // 轨道旋转角度，初始值为0
  @Prop iconSize: number = 140; // 中心图标的大小，默认140
  @Prop orbitRadius: number = 96; // 轨道半径，默认96
  @Prop orbitImageSize: number = 40; // 轨道图标的大小，默认40
  private orbitTimer?: number; // 动画定时器
  private readonly orbitTickMs: number = 16; // 动画帧间隔时间，单位毫秒
  private readonly orbitSpeed: number = 3; // 旋转速度，单位度每帧

  aboutToAppear() {
    this.startOrbitAnimation(); // 组件出现时启动旋转动画
  }

  aboutToDisappear() {
    if (this.orbitTimer !== undefined) {
      clearInterval(this.orbitTimer); // 组件消失时清除定时器
      this.orbitTimer = undefined;
    }
  }

  private startOrbitAnimation() {
    if (this.orbitTimer !== undefined) {
      clearInterval(this.orbitTimer); // 如果已有定时器则先清除
    }
    this.orbitTimer = setInterval(() => {
      this.orbitAngle = (this.orbitAngle + this.orbitSpeed) % 360; // 更新旋转角度
    }, this.orbitTickMs);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) { // 创建堆栈布局，内容居中
      Image($r('app.media.xuexi')) // 加载中心图标
        .width(this.iconSize)
        .height(this.iconSize)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.iconSize / 2)

      Image($r('app.media.luobo')) // 加载轨道图标
        .width(this.orbitImageSize)
        .height(this.orbitImageSize)
        .objectFit(ImageFit.Contain)
        .translate({
          // 根据旋转角度计算轨道图标的位置
          x: this.orbitRadius * Math.cos(this.orbitAngle * Math.PI / 180),
          y: this.orbitRadius * Math.sin(this.orbitAngle * Math.PI / 180)
        })
    }
    .width(this.iconSize + this.orbitRadius * 2) // 设置堆栈布局的总宽度
    .height(this.iconSize + this.orbitRadius * 2) // 设置堆栈布局的总高度
  }
}
