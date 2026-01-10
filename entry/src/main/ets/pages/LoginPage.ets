/**
 * 登录页面 - 用户登录功能
 *
 * 功能概述：
 * - 提供用户名/密码登录表单
 * - 用户协议与隐私政策确认
 * - 登录成功后刷新全局会话状态
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { UserStore } from '../store/UserStore';

@Entry
@Component
export struct LoginPage {
  @State loginUsername: string = '';
  @State loginPassword: string = '';
  @State loginAgree: boolean = false;
  @State rememberPassword: boolean = false;
  @State message: string = '';

  @State headerOpacity: number = 0;
  @State headerOffset: number = 12;
  @State cardOpacity: number = 0;
  @State cardOffset: number = 18;

  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private showAgreement(type: 'user' | 'privacy') {
    const title = type === 'user' ? '用户协议' : '隐私政策';
    const message = type === 'user'
      ? '感谢使用本应用。本协议用于说明账号服务与使用规范，登录即代表您同意遵守相关规则。'
      : '我们仅在提供服务所需范围内处理必要信息，并采取合理措施保护您的数据安全。';
    promptAction.showDialog({
      title,
      message,
      buttons: [{ text: '我知道了', color: '#4C6FFF' }]
    });
  }

  private async handleLogin() {
    this.message = '';
    if (!this.loginAgree) {
      this.message = '请先阅读并同意服务条款再登录';
      return;
    }

    const result = await UserStore.login(this.hostCtx(), this.loginUsername.trim(), this.loginPassword);
    if (result.ok === false) {
      this.message = result.message;
      return;
    }

    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);

    promptAction.showToast({ message: '登录成功' });
    await this.goBack();
  }

  private async goBack() {
    try {
      await router.back();
    } catch (e) {
      await router.pushUrl({ url: 'pages/MinePage' });
    }
  }

  private async openRegisterPage() {
    try {
      await router.pushUrl({ url: 'pages/RegisterPage' });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  build() {
    Stack() {
      Image($r('app.media.bgt'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
      Column() {
        Row() {
          Button('返回', { type: ButtonType.Capsule })
            .fontSize(12)
            .fontColor('#4F46E5')
            .backgroundColor('#EEF2FF')
            .height(28)
            .padding({ left: 10, right: 10 })
            .onClick(async () => {
              await this.goBack();
            })
          Blank().layoutWeight(1)
          Text('登录').fontSize(18).fontWeight(FontWeight.Bold)
          Blank().layoutWeight(1)
        }
        .padding({ top: 12, left: 16, right: 16 })
        .opacity(this.headerOpacity)
        .translate({ x: 0, y: this.headerOffset })

        Column({ space: 12 }) {
          Text('欢迎回来').fontSize(20).fontWeight(FontWeight.Bold)
          Text('登录后可同步点赞、评论等记录').fontSize(12).opacity(0.6)

          TextInput({ text: this.loginUsername, placeholder: '请输入用户名' })
            .onChange((v) => { this.loginUsername = v; })
            .padding({ left: 12, right: 12 })
            .borderRadius(10)
            .backgroundColor('#F6F7FB')

          TextInput({ text: this.loginPassword, placeholder: '请输入密码' })
            .type(InputType.Password)
            .onChange((v) => { this.loginPassword = v; })
            .padding({ left: 12, right: 12 })
            .borderRadius(10)
            .backgroundColor('#F6F7FB')

          Row({ space: 8 }) {
            Checkbox({ name: 'rememberPassword', group: 'loginPrefs' })
              .select(this.rememberPassword)
              .onChange((value: boolean) => { this.rememberPassword = value; })
            Text('记住密码').fontSize(14)
          }
          .alignItems(VerticalAlign.Center)

          Row({ space: 8 }) {
            Checkbox({ name: 'loginAgree', group: 'loginAgreement' })
              .select(this.loginAgree)
              .onChange((value: boolean) => {
                this.loginAgree = value;
                if (value) {
                  this.message = '';
                }
              })
            Text() {
              Span('我已阅读并同意').fontSize(12)
              Span('《用户协议》')
                .fontSize(12)
                .fontColor('#3D6DFF')
                .onClick((): void => {
                  this.showAgreement('user');
                })
              Span('和').fontSize(12)
              Span('《隐私政策》')
                .fontSize(12)
                .fontColor('#3D6DFF')
                .onClick((): void => {
                  this.showAgreement('privacy');
                })
            }
            .onClick(() => {
              const next = !this.loginAgree;
              this.loginAgree = next;
              if (next) {
                this.message = '';
              }
            })
          }
          .alignItems(VerticalAlign.Center)
          .margin({ top: 4 })

          Row({ space: 12 }) {
            Button('登录', { type: ButtonType.Capsule })
              .layoutWeight(1)
              .onClick(async () => { await this.handleLogin(); })
            Button('注册', { type: ButtonType.Capsule })
              .layoutWeight(1)
              .onClick(async () => {
                this.message = '';
                await this.openRegisterPage();
              })
          }
          .margin({ top: 4 })

          if (this.message) {
            Text(this.message).fontSize(14).fontColor(Color.Red).margin({ top: 4 })
          }
        }
        .padding(16)
        .borderRadius(16)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#E9EEF5' })
        .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })
        .opacity(this.cardOpacity)
        .translate({ x: 0, y: this.cardOffset })
      }
      .width('100%')
      .height('100%')
      .padding({ top: 12, left: 16, right: 16 })
      .onAppear(() => {
        animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
          this.headerOpacity = 1;
          this.headerOffset = 0;
        });
        animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
          this.cardOpacity = 1;
          this.cardOffset = 0;
        });
      })
    }
    .width('100%')
    .height('100%')
  }
}