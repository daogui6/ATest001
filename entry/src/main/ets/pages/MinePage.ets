import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
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
  @State username: string = ''
  @State publicName: string = ''
  @State token: string = ''
  @State loginUsername: string = ''
  @State loginPassword: string = ''
  @State regUsername: string = ''
  @State regPassword: string = ''
  @State regNickname: string = ''
  @State message: string = ''
  @State showRegister: boolean = false
  @State rememberPassword: boolean = false

  private hostCtx(): common.UIAbilityContext { //从 ArkUI 页面获取宿主 UIAbility 的 Context，给 Preferences/数据库等系统能力提供稳定的上下文参数
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  async aboutToAppear() {
    await this.loadSession();
  }

  private async loadSession() {
    const user = await UserStore.currentUser(this.hostCtx());
    if (user) {
      this.uid = String(user.id);
      this.nickname = user.nickname || user.username;
      this.bio = user.bio ?? '这个人很懒，还没有签名～';
      this.username = user.username;
      this.publicName = user.publicName;
      this.token = user.token ?? '';
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
      await UserStore.updateProfile(this.hostCtx(), { nickname: this.nickname, bio: this.bio });
    }
  }

  private async persistProfileChanges() {
    this.nickname = this.nickname.trim() || this.username || '用户1';
    this.bio = this.bio.trim() || '这个人很懒，还没有签名～';

    await this.saveAll();
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);
    promptAction.showToast({ message: '已保存个人资料' });
  }

  private async handleLogin() {
    this.message = '';
    const result = await UserStore.login(this.hostCtx(), this.loginUsername.trim(), this.loginPassword);
    if (result.ok === false) {
      this.message = result.message;
      return;
    }

    const user = result.user;
    this.uid = String(user.id);
    this.nickname = user.nickname || user.username;
    this.bio = user.bio ?? '这个人很懒，还没有签名～';
    this.username = user.username;
    this.publicName = user.publicName;
    this.token = user.token ?? '';
    this.isLogin = true;
    this.showRegister = false;
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

    const user = result.user;
    this.uid = String(user.id);
    this.nickname = user.nickname || user.username;
    this.bio = user.bio ?? '这个人是新用户，快来打个招呼吧～';
    this.username = user.username;
    this.publicName = user.publicName;
    this.token = user.token ?? '';
    this.isLogin = true;
    this.showRegister = false;
    await this.saveAll();
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);
  }

  private resetRegisterForm() {
    this.regUsername = '';
    this.regPassword = '';
    this.regNickname = '';
  }

  private handleLogoutState() {
    this.uid = '0';
    this.username = '';
    this.publicName = '';
    this.token = '';
    this.isLogin = false;
    this.showRegister = false;
    this.message = '';
    this.resetRegisterForm();
    if (!this.rememberPassword) {
      this.loginPassword = '';
    }
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
          Row({ space: 8 }) {
            Checkbox({ name: 'rememberPassword', group: 'loginPrefs' })
              .select(this.rememberPassword)
              .onChange((value: boolean) => { this.rememberPassword = value; })
            Text('记住密码').fontSize(14)
          }
          .alignItems(VerticalAlign.Center)
          Button('登录', { type: ButtonType.Capsule })
            .onClick(async () => { await this.handleLogin(); })

          Divider().margin({ top: 6, bottom: 6 })

          Button(this.showRegister ? '返回登录' : '注册', { type: ButtonType.Capsule })
            .onClick(() => {
              this.message = '';
              this.showRegister = !this.showRegister;
            })

          if (this.showRegister) {
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
          }

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
          Text('账号信息').fontSize(16).fontWeight(FontWeight.Medium)
          Column({ space: 6 }) {
            Text(`用户ID：${this.uid}`).fontSize(14)
            Text(`用户名：${this.username || '未获取'}`).fontSize(14)
            Text(`公开昵称：${this.publicName || this.nickname}`).fontSize(14)
            Text(`Token：${this.token || '暂无'}`).fontSize(14).opacity(0.7)
            Text(`昵称：${this.nickname}`).fontSize(14)
            Text(`签名：${this.bio}`).fontSize(14).opacity(0.7)
          }

          Text('编辑昵称').fontSize(14).opacity(0.7)
          TextInput({ text: this.nickname, placeholder: '请输入昵称' })
            .onChange((v) => { // 首先更新本地状态，统一点击保存时再持久化
              this.nickname = v;
            })

          Text('编辑签名').fontSize(14).opacity(0.7).margin({ top: 6 })
          TextInput({ text: this.bio, placeholder: '请输入签名' })
            .onChange((v) => {
              this.bio = v
            })

          Button('保存资料', { type: ButtonType.Capsule })
            .onClick(async () => {
              await this.persistProfileChanges();
            })
            .margin({ top: 6 })

          Button('退出登录', { type: ButtonType.Capsule })
            .onClick(async () => {
              this.handleLogoutState();
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
