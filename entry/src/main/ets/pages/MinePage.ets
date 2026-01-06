import type common from '@ohos.app.ability.common';
import { Prefs } from '../store/Prefs';
import { UserStore } from '../store/UserStore';

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
  @State loginUsername: string = ''
  @State loginPassword: string = ''
  @State regUsername: string = ''
  @State regPassword: string = ''
  @State regNickname: string = ''
  @State message: string = ''

  private hostCtx(): common.UIAbilityContext { //从 ArkUI 页面获取宿主 UIAbility 的 Context，给 Preferences/数据库等系统能力提供稳定的上下文参数
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  async aboutToAppear() {
    await this.loadSession();
  }

  private async loadSession() {
    const user = await UserStore.currentUser(this.hostCtx());
    if (user) {
      this.uid = user.username;
      this.nickname = user.nickname || user.username;
      this.bio = user.bio ?? '这个人很懒，还没有签名～';
      this.isLogin = true;
      return;
    }

    const uid = await Prefs.getString(this.hostCtx(), this.KEY_UID, '0');
    this.isLogin = (uid !== '0');

    this.nickname = await Prefs.getString(this.hostCtx(), this.KEY_NICK, '用户1');
    this.bio = await Prefs.getString(this.hostCtx(), this.KEY_BIO, '这个人很懒，还没有签名～');
    this.uid = uid;
  }

  private async saveAll() {
    await Prefs.putString(this.hostCtx(), this.KEY_UID, this.uid);
    await Prefs.putBool(this.hostCtx(), this.KEY_LOGIN, this.isLogin); // 可留可不留，留着兼容
    await Prefs.putString(this.hostCtx(), this.KEY_NICK, this.nickname);
    await Prefs.putString(this.hostCtx(), this.KEY_BIO, this.bio);

    if (this.isLogin && this.uid !== '0') {
      await UserStore.updateProfile(this.hostCtx(), this.uid, { nickname: this.nickname, bio: this.bio });
    }
  }

  private async handleLogin() {
    this.message = '';
    const user = await UserStore.login(this.hostCtx(), this.loginUsername.trim(), this.loginPassword);
    if (!user) {
      this.message = '用户名或密码错误';
      return;
    }

    this.uid = user.username;
    this.nickname = user.nickname || user.username;
    this.bio = user.bio ?? '这个人很懒，还没有签名～';
    this.isLogin = true;
    await this.saveAll();
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);
  }

  private async handleRegister() {
    this.message = '';
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

    this.uid = this.regUsername.trim();
    this.nickname = this.regNickname.trim() || this.regUsername.trim();
    this.bio = '这个人是新用户，快来打个招呼吧～';
    this.isLogin = true;
    await this.saveAll();
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);
  }

  build() {
    Column() {
      Text('我的').fontSize(22).fontWeight(FontWeight.Bold).margin({ top: 16, left: 16, bottom: 12 })

      if (!this.isLogin) {
        Column({ space: 12 }) {
          Text('登录').fontSize(16)
          TextInput({ text: this.loginUsername, placeholder: '请输入用户名' })
            .onChange((v) => { this.loginUsername = v; })
          TextInput({ text: this.loginPassword, placeholder: '请输入密码' })
            .type(InputType.Password)
            .onChange((v) => { this.loginPassword = v; })
          Button('登录', { type: ButtonType.Capsule })
            .onClick(async () => { await this.handleLogin(); })

          Divider().margin({ top: 6, bottom: 6 })

          Text('注册').fontSize(16)
          TextInput({ text: this.regUsername, placeholder: '设置用户名' })
            .onChange((v) => { this.regUsername = v; })
          TextInput({ text: this.regPassword, placeholder: '设置密码' })
            .type(InputType.Password)
            .onChange((v) => { this.regPassword = v; })
          TextInput({ text: this.regNickname, placeholder: '昵称（可选）' })
            .onChange((v) => { this.regNickname = v; })
          Button('注册并登录', { type: ButtonType.Capsule })
            .onClick(async () => { await this.handleRegister(); })

          if (this.message) {
            Text(this.message).fontSize(14).fontColor(Color.Red).margin({ top: 4 })
          }
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
              await UserStore.logout(this.hostCtx());
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
