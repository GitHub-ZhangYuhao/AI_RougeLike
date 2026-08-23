import automator from 'miniprogram-automator';

async function testMinigame() {
    console.log('连接微信开发者工具自动化...');
    
    try {
        // 连接到自动化端口
        const miniProgram = await automator.connect({
            port: 9420,
        });
        
        console.log('微信开发者工具自动化连接成功');
        
        // 等待游戏加载
        console.log('等待游戏加载...');
        await new Promise(resolve => setTimeout(resolve, 8000));
        
        // 获取当前页面信息
        const page = await miniProgram.currentPage();
        console.log('当前页面:', page.path);
        
        // 截图保存
        await miniProgram.screenshot({
            path: 'C:\\WorkSpace\\AIGame\\Experimental\\wechat_minigame_test.png'
        });
        console.log('截图已保存到 Experimental/wechat_minigame_test.png');
        
        // 检查系统信息
        console.log('检查系统信息...');
        const systemInfo = await miniProgram.systemInfo();
        console.log('系统信息:', systemInfo);
        
        // 检查页面状态
        console.log('检查页面状态...');
        const pageState = await page.data();
        console.log('页面数据:', pageState);
        
        // 关闭自动化连接
        await miniProgram.disconnect();
        console.log('测试完成');
        
    } catch (error) {
        console.error('测试失败:', error);
        throw error;
    }
}

testMinigame();