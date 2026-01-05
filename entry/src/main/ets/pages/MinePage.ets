import type common from '@ohos.app.ability.common';
import { Prefs } from '../store/Prefs';

@Component
export struct MinePage {
  // key 约定
  private KEY_UID = 'session.userId';
  private KEY_LOGIN = 'session.isLogin';
  private KEY_NICK = 'profile.nickname';
  private KEY_BIO = 'profile.bio';
  @State isLogin: boolean = false
  @State nickname: string = '用户1'
  @State bio: string = '这个人很懒，还没有签名～'
  @State uid: string = '0'

  private hostCtx(): common.UIAbilityContext { //从 ArkUI 页面获取宿主 UIAbility 的 Context，给 Preferences/数据库等系统能力提供稳定的上下文参数
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  async aboutToAppear() {
    const uid = await Prefs.getString(this.hostCtx(), this.KEY_UID, '0');
    this.isLogin = (uid !== '0');

    this.nickname = await Prefs.getString(this.hostCtx(), this.KEY_NICK, '用户1');
    this.bio = await Prefs.getString(this.hostCtx(), this.KEY_BIO, '这个人很懒，还没有签名～');
  }

  private async saveAll() {
    await Prefs.putString(this.hostCtx(), this.KEY_UID, this.uid);
    await Prefs.putBool(this.hostCtx(), this.KEY_LOGIN, this.isLogin); // 可留可不留，留着兼容
    await Prefs.putString(this.hostCtx(), this.KEY_NICK, this.nickname);
    await Prefs.putString(this.hostCtx(), this.KEY_BIO, this.bio);
  }

  build() {
    Column() {
      Text('我的').fontSize(22).fontWeight(FontWeight.Bold).margin({ top: 16, left: 16, bottom: 12 })

      if (!this.isLogin) {
        Column({ space: 10 }) {
          Text('未登录').fontSize(16)

          Button('一键登录（本地）', { type: ButtonType.Capsule })
            .onClick(async () => {
              this.uid = '1';
              this.isLogin = true;
              await this.saveAll();
              AppStorage.setOrCreate('session_version', 0);
              const v = (AppStorage.get('session_version') as number) ?? 0;
              AppStorage.set('session_version', v + 1);
            })
        }
        .padding(16)
        .margin(16)
        .borderRadius(12)
        .backgroundColor('#F5F5F5')
      } else {
        Column({ space: 12 }) {
          Text(`昵称：${this.nickname}`).fontSize(18)
          Text(`签名：${this.bio}`).fontSize(14).opacity(0.7)

          Text('编辑昵称').fontSize(14).opacity(0.7)
          TextInput({ text: this.nickname, placeholder: '请输入昵称' })
            .onChange(async (v) => { //边输入边保存数据防止丢失
              this.nickname = v;
              await this.saveAll();
            })

          Text('编辑签名').fontSize(14).opacity(0.7).margin({ top: 6 })
          TextInput({ text: this.bio, placeholder: '请输入签名' })
            .onChange(async (v) => {
              this.bio = v;
              await this.saveAll();
            })

          Button('退出登录', { type: ButtonType.Capsule })
            .onClick(async () => {
              this.uid = '0';
              this.isLogin = false;
              await this.saveAll();
              AppStorage.setOrCreate('session_version', 0);
              const v = (AppStorage.get('session_version') as number) ?? 0;
              AppStorage.set('session_version', v + 1);
            })
            .margin({ top: 10 })
        }
        .padding(16)
        .margin(16)
        .borderRadius(12)
        .backgroundColor('#F5F5F5')
      }
    }
    .width('100%')
    .height('100%')
  }
}
