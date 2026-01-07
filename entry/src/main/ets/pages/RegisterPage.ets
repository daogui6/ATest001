import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { UserStore } from '../store/UserStore';

@Entry
@Component
export struct RegisterPage {
  @State regUsername: string = ''
  @State regPassword: string = ''
  @State regNickname: string = ''
  @State registerAgree: boolean = false
  @State message: string = ''

  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private async handleRegister() {
    this.message = '';
    if (!this.registerAgree) {
      this.message = '请先阅读并同意服务条款再注册';
      return;
    }
    const result = await UserStore.register(
      this.hostCtx(),
      this.regUsername.trim(),
      this.regPassword,
      this.regNickname.trim() || this.regUsername.trim(),
      '这个人是新用户，快来打个招呼吧～'
    );

    if (result.ok === false) {
      this.message = result.message;
      return;
    }

    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);
    promptAction.showToast({ message: '注册成功，已登录' });
    await this.goBack();
  }

  private async goBack() {
    try {
      await router.back();
    } catch (e) {
      await router.pushUrl({ url: 'pages/MinePage' });
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('←')
          .fontSize(20)
          .onClick(async () => {
            await this.goBack();
          })
        Text('注册')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
      }
      .height(52)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16 })

      Scroll() {
        Column({ space: 12 }) {
          Text('注册').fontSize(16).fontWeight(FontWeight.Medium)
          TextInput({ text: this.regUsername, placeholder: '设置用户名' })
            .onChange((v) => { this.regUsername = v; })
            .padding({ left: 12, right: 12 })
            .borderRadius(10)
            .backgroundColor('#F6F7FB')
          TextInput({ text: this.regPassword, placeholder: '设置密码' })
            .type(InputType.Password)
            .onChange((v) => { this.regPassword = v; })
            .padding({ left: 12, right: 12 })
            .borderRadius(10)
            .backgroundColor('#F6F7FB')
          TextInput({ text: this.regNickname, placeholder: '昵称（可选）' })
            .onChange((v) => { this.regNickname = v; })
            .padding({ left: 12, right: 12 })
            .borderRadius(10)
            .backgroundColor('#F6F7FB')
          Row({ space: 8 }) {
            Checkbox({ name: 'registerAgree', group: 'registerAgreement' })
              .select(this.registerAgree)
              .onChange((value: boolean) => {
                this.registerAgree = value;
                if (value) {
                  this.message = '';
                }
              })
            Text('我已阅读并同意《用户协议》和《隐私政策》').fontSize(12)
              .onClick(() => {
                const next = !this.registerAgree;
                this.registerAgree = next;
                if (next) {
                  this.message = '';
                }
              })
          }
          .alignItems(VerticalAlign.Center)
          .margin({ top: 4 })
          Button('注册并登录', { type: ButtonType.Capsule })
            .onClick(async () => { await this.handleRegister(); })

          if (this.message) {
            Text(this.message).fontSize(14).fontColor(Color.Red).margin({ top: 4 })
          }
        }
        .padding(16)
        .borderRadius(16)
        .backgroundColor('#FFFFFF')
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7FB')
  }
}