import type common from '@ohos.app.ability.common';
import { Prefs } from '../store/Prefs';
import { UserStore } from '../store/UserStore';
import type { ThemePalette } from '../store/ThemeStore';
import { DARK_MODE_STORAGE_KEY, ThemeStore } from '../store/ThemeStore';

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
  @State showRegister: boolean = false
  @State rememberPassword: boolean = false
  @StorageLink(DARK_MODE_STORAGE_KEY)
  isDarkMode: boolean = false

  private hostCtx(): common.UIAbilityContext { //从 ArkUI 页面获取宿主 UIAbility 的 Context，给 Preferences/数据库等系统能力提供稳定的上下文参数
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private palette(): ThemePalette {
    return ThemeStore.palette(this.isDarkMode);
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

  private async updateDarkMode(enabled: boolean) {
    await ThemeStore.setDarkMode(this.hostCtx(), enabled);
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

    this.uid = this.regUsername.trim();
    this.nickname = this.regNickname.trim() || this.regUsername.trim();
    this.bio = '这个人是新用户，快来打个招呼吧～';
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
    this.isLogin = false;
    this.showRegister = false;
    this.message = '';
    this.resetRegisterForm();
    if (!this.rememberPassword) {
      this.loginPassword = '';
    }
  }

  build() {
    const colors = this.palette();
    Column() {
      Text('我的').fontSize(22).fontWeight(FontWeight.Bold).fontColor(colors.primaryText).margin({ top: 16, left: 16, bottom: 12 })

      Row() {
        Text('夜间模式').fontSize(14).fontColor(colors.primaryText)
        Blank().layoutWeight(1)
        Checkbox({ name: 'darkMode', group: 'settings' })
          .select(this.isDarkMode)
          .onChange(async (value: boolean) => {
            this.isDarkMode = value;
            await this.updateDarkMode(value);
          })
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 16, right: 16, bottom: 8 })

      if (!this.isLogin) {
        Column({ space: 12 }) {
          Text('登录').fontSize(16).fontColor(colors.primaryText)
          TextInput({ text: this.loginUsername, placeholder: '请输入用户名' })
            .backgroundColor(colors.inputBackground)
            .fontColor(colors.primaryText)
            .onChange((v) => { this.loginUsername = v; })
          TextInput({ text: this.loginPassword, placeholder: '请输入密码' })
            .type(InputType.Password)
            .backgroundColor(colors.inputBackground)
            .fontColor(colors.primaryText)
            .onChange((v) => { this.loginPassword = v; })
          Row({ space: 8 }) {
            Checkbox({ name: 'rememberPassword', group: 'loginPrefs' })
              .select(this.rememberPassword)
              .onChange((value: boolean) => { this.rememberPassword = value; })
            Text('记住密码').fontSize(14).fontColor(colors.primaryText)
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
            Text('注册').fontSize(16).fontColor(colors.primaryText)
            TextInput({ text: this.regUsername, placeholder: '设置用户名' })
              .backgroundColor(colors.inputBackground)
              .fontColor(colors.primaryText)
              .onChange((v) => { this.regUsername = v; })
            TextInput({ text: this.regPassword, placeholder: '设置密码' })
              .type(InputType.Password)
              .backgroundColor(colors.inputBackground)
              .fontColor(colors.primaryText)
              .onChange((v) => { this.regPassword = v; })
            TextInput({ text: this.regNickname, placeholder: '昵称（可选）' })
              .backgroundColor(colors.inputBackground)
              .fontColor(colors.primaryText)
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
        .backgroundColor(colors.card)
      } else {
        Column({ space: 12 }) {
          Text(`昵称：${this.nickname}`).fontSize(18).fontColor(colors.primaryText)
          Text(`签名：${this.bio}`).fontSize(14).opacity(0.7).fontColor(colors.secondaryText)

          Text('编辑昵称').fontSize(14).opacity(0.7).fontColor(colors.secondaryText)
          TextInput({ text: this.nickname, placeholder: '请输入昵称' })
            .backgroundColor(colors.inputBackground)
            .fontColor(colors.primaryText)
            .onChange(async (v) => { //边输入边保存数据防止丢失
              this.nickname = v;
              await this.saveAll();
            })

          Text('编辑签名').fontSize(14).opacity(0.7).fontColor(colors.secondaryText).margin({ top: 6 })
          TextInput({ text: this.bio, placeholder: '请输入签名' })
            .backgroundColor(colors.inputBackground)
            .fontColor(colors.primaryText)
            .onChange(async (v) => {
              this.bio = v;
              await this.saveAll();
            })

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
        .backgroundColor(colors.card)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(colors.background)
  }
}
