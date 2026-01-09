/**
 * 用户注册页面组件
 * 
 * 功能说明：
 * 1. 提供用户注册功能，包括用户名、密码、确认密码、邮箱等字段
 * 2. 实现表单验证和错误提示
 * 3. 支持注册按钮状态管理和防重复提交
 * 4. 包含注册成功后的跳转逻辑
 * 
 * 使用说明：
 * 1. 将此文件放置在项目的pages目录下
 * 2. 在需要使用的页面中导入并调用
 * 3. 根据实际需求调整样式和验证规则
 */

// 导入HarmonyOS ArkTS核心模块
import router from '@ohos.router';

/**
 * 注册页面组件
 * @Component 装饰器声明这是一个自定义组件
 */
@Component
struct RegisterPage {
  // 用户名输入框状态，使用@State装饰器实现数据双向绑定
  @State username: string = '';
  
  // 密码输入框状态
  @State password: string = '';
  
  // 确认密码输入框状态
  @State confirmPassword: string = '';
  
  // 邮箱输入框状态
  @State email: string = '';
  
  // 验证码输入框状态
  @State verificationCode: string = '';
  
  // 是否显示密码
  @State showPassword: boolean = false;
  
  // 是否显示确认密码
  @State showConfirmPassword: boolean = false;
  
  // 注册按钮是否可用
  @State isRegisterEnabled: boolean = false;
  
  // 是否正在提交注册
  @State isSubmitting: boolean = false;
  
  // 验证码倒计时
  @State countdown: number = 0;
  
  // 错误信息集合
  @State errors: {
    username: string,
    password: string,
    confirmPassword: string,
    email: string,
    verificationCode: string
  } = {
    username: '',
    password: '',
    confirmPassword: '',
    email: '',
    verificationCode: ''
  };

  /**
   * 组件构建方法
   * 定义页面的UI结构和布局
   */
  build() {
    Column({ space: 0 }) {
      // 页面标题区域
      this.buildHeader()
      
      // 表单内容区域
      this.buildForm()
      
      // 注册按钮区域
      this.buildFooter()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .padding({ left: 24, right: 24 })
  }

  /**
   * 构建页面头部
   * 包含标题和返回按钮
   */
  @Builder
  buildHeader() {
    Column({ space: 20 }) {
      // 返回按钮
      Row() {
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
          .onClick(() => {
            // 返回上一页
            router.back();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      // 页面标题
      Text('用户注册')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ bottom: 40 })
    }
    .width('100%')
    .margin({ top: 60 })
  }

  /**
   * 构建表单区域
   * 包含所有输入字段和验证逻辑
   */
  @Builder
  buildForm() {
    Column({ space: 16 }) {
      // 用户名输入框
      this.buildInputField(
        '用户名',
        '请输入用户名',
        this.username,
        (value: string) => {
          this.username = value;
          this.validateUsername(value);
          this.updateRegisterButtonState();
        },
        this.errors.username
      )

      // 邮箱输入框
      this.buildInputField(
        '邮箱',
        '请输入邮箱地址',
        this.email,
        (value: string) => {
          this.email = value;
          this.validateEmail(value);
          this.updateRegisterButtonState();
        },
        this.errors.email
      )

      // 密码输入框
      this.buildPasswordField(
        '密码',
        '请输入密码',
        this.password,
        (value: string) => {
          this.password = value;
          this.validatePassword(value);
          this.updateRegisterButtonState();
        },
        this.errors.password,
        this.showPassword,
        () => {
          this.showPassword = !this.showPassword;
        }
      )

      // 确认密码输入框
      this.buildPasswordField(
        '确认密码',
        '请再次输入密码',
        this.confirmPassword,
        (value: string) => {
          this.confirmPassword = value;
          this.validateConfirmPassword(value);
          this.updateRegisterButtonState();
        },
        this.errors.confirmPassword,
        this.showConfirmPassword,
        () => {
          this.showConfirmPassword = !this.showConfirmPassword;
        }
      )

      // 验证码输入框和获取验证码按钮
      this.buildVerificationCodeField()
    }
    .width('100%')
  }

  /**
   * 构建普通输入框组件
   * @param label 标签文本
   * @param placeholder 占位符文本
   * @param value 输入框值
   * @param onChange 值改变回调
   * @param error 错误信息
   */
  @Builder
  buildInputField(label: string, placeholder: string, value: string, 
                 onChange: (value: string) => void, error: string) {
    Column({ space: 8 }) {
      // 标签
      Text(label)
        .fontSize(16)
        .fontColor('#333333')
        .width('100%')
        .textAlign(TextAlign.Start)

      // 输入框
      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(48)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .padding({ left: 16, right: 16 })
        .fontSize(16)
        .onChange((value: string) => {
          onChange(value);
        })

      // 错误提示
      if (error) {
        Text(error)
          .fontSize(12)
          .fontColor('#FF4444')
          .width('100%')
          .textAlign(TextAlign.Start)
      }
    }
    .width('100%')
  }

  /**
   * 构建密码输入框组件
   * @param label 标签文本
   * @param placeholder 占位符文本
   * @param value 输入框值
   * @param onChange 值改变回调
   * @param error 错误信息
   * @param showPassword 是否显示密码
   * @param onToggleVisibility 切换显示状态回调
   */
  @Builder
  buildPasswordField(label: string, placeholder: string, value: string,
                    onChange: (value: string) => void, error: string,
                    showPassword: boolean, onToggleVisibility: () => void) {
    Column({ space: 8 }) {
      // 标签
      Text(label)
        .fontSize(16)
        .fontColor('#333333')
        .width('100%')
        .textAlign(TextAlign.Start)

      // 输入框和显示/隐藏按钮
      Row() {
        TextInput({ 
          text: value, 
          placeholder: placeholder,
          type: showPassword ? InputType.Normal : InputType.Password
        })
          .flexGrow(1)
          .height(48)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .padding({ left: 16, right: 16 })
          .fontSize(16)
          .onChange((value: string) => {
            onChange(value);
          })

        // 显示/隐藏密码按钮
        Image(showPassword ? $r('app.media.ic_visibility_off') : $r('app.media.ic_visibility'))
          .width(24)
          .height(24)
          .margin({ left: 12 })
          .onClick(() => {
            onToggleVisibility();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 错误提示
      if (error) {
        Text(error)
          .fontSize(12)
          .fontColor('#FF4444')
          .width('100%')
          .textAlign(TextAlign.Start)
      }
    }
    .width('100%')
  }

  /**
   * 构建验证码输入区域
   * 包含验证码输入框和获取验证码按钮
   */
  @Builder
  buildVerificationCodeField() {
    Column({ space: 8 }) {
      Text('验证码')
        .fontSize(16)
        .fontColor('#333333')
        .width('100%')
        .textAlign(TextAlign.Start)

      Row() {
        // 验证码输入框
        TextInput({ 
          text: this.verificationCode, 
          placeholder: '请输入验证码'
        })
          .flexGrow(1)
          .height(48)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .padding({ left: 16, right: 16 })
          .fontSize(16)
          .onChange((value: string) => {
            this.verificationCode = value;
            this.validateVerificationCode(value);
            this.updateRegisterButtonState();
          })

        // 获取验证码按钮
        Button(this.countdown > 0 ? `${this.countdown}s后重新获取` : '获取验证码')
          .width(120)
          .height(48)
          .fontSize(14)
          .backgroundColor(this.countdown > 0 ? '#CCCCCC' : '#007DFF')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .enabled(this.countdown === 0 && this.email !== '' && this.errors.email === '')
          .onClick(() => {
            this.getVerificationCode();
          })
          .margin({ left: 12 })
      }
      .width('100%')

      // 错误提示
      if (this.errors.verificationCode) {
        Text(this.errors.verificationCode)
          .fontSize(12)
          .fontColor('#FF4444')
          .width('100%')
          .textAlign(TextAlign.Start)
      }
    }
    .width('100%')
  }

  /**
   * 构建页面底部
   * 包含注册按钮和用户协议
   */
  @Builder
  buildFooter() {
    Column({ space: 20 }) {
      // 用户协议提示
      Row() {
        Text('注册即表示同意')
          .fontSize(14)
          .fontColor('#666666')
        
        Text('《用户协议》')
          .fontSize(14)
          .fontColor('#007DFF')
          .onClick(() => {
            // 跳转到用户协议页面
            console.log('跳转到用户协议页面');
          })
          .margin({ left: 4 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      // 注册按钮
      Button(this.isSubmitting ? '注册中...' : '注册')
        .width('100%')
        .height(56)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.isRegisterEnabled ? '#007DFF' : '#CCCCCC')
        .fontColor('#FFFFFF')
        .borderRadius(28)
        .enabled(this.isRegisterEnabled && !this.isSubmitting)
        .onClick(() => {
          this.handleRegister();
        })
        .margin({ top: 20 })
    }
    .width('100%')
    .margin({ top: 40, bottom: 60 })
  }

  /**
   * 验证用户名
   * @param username 用户名
   */
  validateUsername(username: string): void {
    if (!username) {
      this.errors.username = '用户名不能为空';
    } else if (username.length < 3) {
      this.errors.username = '用户名长度不能少于3个字符';
    } else if (username.length > 20) {
      this.errors.username = '用户名长度不能超过20个字符';
    } else if (!/^[a-zA-Z0-9_]+$/.test(username)) {
      this.errors.username = '用户名只能包含字母、数字和下划线';
    } else {
      this.errors.username = '';
    }
  }

  /**
   * 验证邮箱
   * @param email 邮箱地址
   */
  validateEmail(email: string): void {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    
    if (!email) {
      this.errors.email = '邮箱不能为空';
    } else if (!emailRegex.test(email)) {
      this.errors.email = '请输入有效的邮箱地址';
    } else {
      this.errors.email = '';
    }
  }

  /**
   * 验证密码
   * @param password 密码
   */
  validatePassword(password: string): void {
    if (!password) {
      this.errors.password = '密码不能为空';
    } else if (password.length < 6) {
      this.errors.password = '密码长度不能少于6个字符';
    } else if (password.length > 20) {
      this.errors.password = '密码长度不能超过20个字符';
    } else if (!/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/.test(password)) {
      this.errors.password = '密码必须包含大小写字母和数字';
    } else {
      this.errors.password = '';
    }
  }

  /**
   * 验证确认密码
   * @param confirmPassword 确认密码
   */
  validateConfirmPassword(confirmPassword: string): void {
    if (!confirmPassword) {
      this.errors.confirmPassword = '请再次输入密码';
    } else if (confirmPassword !== this.password) {
      this.errors.confirmPassword = '两次输入的密码不一致';
    } else {
      this.errors.confirmPassword = '';
    }
  }

  /**
   * 验证验证码
   * @param code 验证码
   */
  validateVerificationCode(code: string): void {
    if (!code) {
      this.errors.verificationCode = '验证码不能为空';
    } else if (code.length !== 6) {
      this.errors.verificationCode = '验证码必须是6位数字';
    } else if (!/^\d+$/.test(code)) {
      this.errors.verificationCode = '验证码只能包含数字';
    } else {
      this.errors.verificationCode = '';
    }
  }

  /**
   * 更新注册按钮状态
   * 根据表单验证结果决定按钮是否可用
   */
  updateRegisterButtonState(): void {
    const hasErrors = Object.values(this.errors).some(error => error !== '');
    const allFieldsFilled = this.username && this.email && this.password && 
                           this.confirmPassword && this.verificationCode;
    
    this.isRegisterEnabled = !hasErrors && allFieldsFilled;
  }

  /**
   * 获取验证码
   * 模拟发送验证码到邮箱
   */
  getVerificationCode(): void {
    if (this.countdown > 0) {
      return;
    }

    // 开始倒计时
    this.countdown = 60;
    const timer = setInterval(() => {
      this.countdown--;
      if (this.countdown <= 0) {
        clearInterval(timer);
      }
    }, 1000);

    // 模拟发送验证码请求
    console.log(`发送验证码到邮箱: ${this.email}`);
    // 实际项目中这里应该调用API发送验证码
  }

  /**
   * 处理注册逻辑
   */
  async handleRegister(): Promise<void> {
    // 防止重复提交
    if (this.isSubmitting) {
      return;
    }

    this.isSubmitting = true;

    try {
      // 模拟注册API调用
      console.log('开始注册...');
      
      // 构造注册数据
      const registerData = {
        username: this.username,
        email: this.email,
        password: this.password,
        verificationCode: this.verificationCode
      };

      // 模拟网络请求延迟
      await new Promise(resolve => setTimeout(resolve, 2000));

      // 模拟注册成功
      console.log('注册成功:', registerData);

      // 注册成功后的操作
      this.onRegisterSuccess();

    } catch (error) {
      console.error('注册失败:', error);
      // 处理注册失败的情况
      this.onRegisterFailed('注册失败，请稍后重试');
    } finally {
      this.isSubmitting = false;
    }
  }

  /**
   * 注册成功回调
   */
  onRegisterSuccess(): void {
    // 显示成功提示
    console.log('注册成功！');
    
    // 跳转到登录页面或首页
    router.replaceUrl({
      url: 'pages/LoginPage'
    });
  }

  /**
   * 注册失败回调
   * @param message 错误消息
   */
  onRegisterFailed(message: string): void {
    // 显示错误提示
    console.error('注册失败:', message);
    
    // 在实际项目中，这里可以显示Toast或Dialog提示用户
    this.errors.verificationCode = message;
  }

  /**
   * 组件生命周期 - 页面显示时调用
   */
  aboutToAppear(): void {
    console.log('RegisterPage aboutToAppear');
    // 页面显示时的初始化操作
  }

  /**
   * 组件生命周期 - 页面隐藏时调用
   */
  aboutToDisappear(): void {
    console.log('RegisterPage aboutToDisappear');
    // 页面隐藏时的清理操作
  }
}