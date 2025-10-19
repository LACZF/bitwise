from setuptools import setup

APP = ['bitwise_calculator.py']  # 你的主脚本文件名
DATA_FILES = []
OPTIONS = {
    'argv_emulation': False,  # 通常建议设为False以避免启动问题
    # 'packages': ['requests', 'tk'],  # 在这里列出你的脚本依赖的第三方库
    # 'iconfile': 'app_icon.icns',  # 应用图标文件
    'plist': {
        'CFBundleName': 'bitwise',
        'CFBundleVersion': '1.0.0',
    }
}

setup(
    app=APP,
    data_files=DATA_FILES,
    options={'py2app': OPTIONS},
    setup_requires=['py2app'],
)
