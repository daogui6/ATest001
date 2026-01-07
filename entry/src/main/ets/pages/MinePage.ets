import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
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
  @State loginAgree: boolean = false
  @State regUsername: string = ''
  @State regPassword: string = ''
  @State regNickname: string = ''
  @State registerAgree: boolean = false
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
    if (!this.loginAgree) {
      this.message = '请先阅读并同意服务条款再登录';
      return;
    }
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
    this.loginAgree = false;
    this.registerAgree = false;
    this.resetRegisterForm();
    if (!this.rememberPassword) {
      this.loginPassword = '';
    }
  }

  private async handleLogout() {
    this.handleLogoutState();
    await this.saveAll();
    await UserStore.logout(this.hostCtx());

    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);

    promptAction.showToast({ message: '已退出登录' });
  }

  private async openHistory() {
    try {
      await router.pushUrl({ url: 'pages/HistoryPage' });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  private async openLiked() {
    if (!this.isLogin || this.uid === '0') {
      promptAction.showToast({ message: '请先登录后查看点赞记录' });
      return;
    }
    try {
      await router.pushUrl({ url: 'pages/LikedPage' });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  private async openCommented() {
    if (!this.isLogin || this.uid === '0') {
      promptAction.showToast({ message: '请先登录后查看评论记录' });
      return;
    }
    try {
      await router.pushUrl({ url: 'pages/CommentedPage' });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  build() {
    Column() {
      Row() {
        Text('我的')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
      }
      .height(52)
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 16 }) {
          Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.startIcon'))
                .width(52)
                .height(52)
                .borderRadius(26)
                .backgroundColor('#4C6FFF')
                .objectFit(ImageFit.Cover)
              Text(this.isLogin ? (this.nickname ? this.nickname.slice(0, 1) : '我') : '访')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .textAlign(TextAlign.Center)
            }
            .width(52)
            .height(52)

            Column({ space: 4 }) {
              Text(this.isLogin ? this.nickname : '欢迎来到我的主页')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
              Text(
                this.isLogin
                  ? `ID：${this.uid} · ${this.publicName || this.username || '未设置昵称'}`
                  : '登录后可同步点赞、评论等记录'
              )
                .fontSize(12)
                .opacity(0.6)
              if (this.isLogin) {
                Text(this.bio).fontSize(12).opacity(0.7).maxLines(2)
              }
            }
            .layoutWeight(1)
          }
          .padding(16)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')

          Column({ space: 12 }) {
            Row() {
              Text('我的足迹').fontSize(16).fontWeight(FontWeight.Medium)
            }
            Row({ space: 12 }) {
              Column({ space: 6 }) {
                Text('🕘').fontSize(22)
                Text('浏览历史').fontSize(12)
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .onClick(async () => await this.openHistory())

              Column({ space: 6 }) {
                Text('❤️').fontSize(22)
                Text('点赞过').fontSize(12)
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .onClick(async () => await this.openLiked())

              Column({ space: 6 }) {
                Text('💬').fontSize(22)
                Text('评论过').fontSize(12)
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .onClick(async () => await this.openCommented())
            }
          }
          .padding(16)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')

          if (!this.isLogin) {
            Column({ space: 12 }) {
              Text('登录').fontSize(16).fontWeight(FontWeight.Medium)
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
                Text('我已阅读并同意《用户协议》和《隐私政策》').fontSize(12)
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
              }

              if (this.message) {
                Text(this.message).fontSize(14).fontColor(Color.Red).margin({ top: 4 })
              }
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
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
                .padding({ left: 12, right: 12 })
                .borderRadius(10)
                .backgroundColor('#F6F7FB')

              Text('编辑签名').fontSize(14).opacity(0.7).margin({ top: 6 })
              TextInput({ text: this.bio, placeholder: '请输入签名' })
                .onChange((v) => {
                  this.bio = v
                })
                .padding({ left: 12, right: 12 })
                .borderRadius(10)
                .backgroundColor('#F6F7FB')

              Button('保存资料', { type: ButtonType.Capsule })
                .onClick(async () => {
                  await this.persistProfileChanges();
                })
                .margin({ top: 6 })

              Button('退出登录', { type: ButtonType.Capsule })
                .onClick(async () => {
                  await this.handleLogout();
                })
                .margin({ top: 10 })
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7FB')
  }
}
