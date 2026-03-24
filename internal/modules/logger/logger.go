package logger

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"

	"github.com/cihub/seelog"
	"gopkg.in/macaron.v1"
)

// 全局变量来存储配置和日志路径参数
var (
	CommandLogPath string
	CommandConfigPath string
)

// 日志库

type Level int8

var logger seelog.LoggerInterface

const (
	DEBUG = iota
	INFO
	WARN
	ERROR
	FATAL
)

func InitLogger() {
	config := getLogConfig()
	l, err := seelog.LoggerFromConfigAsString(config)
	if err != nil {
		panic(err)
	}
	logger = l
}

func Debug(v ...interface{}) {
	if macaron.Env != macaron.DEV {
		return
	}
	write(DEBUG, v)
}

func Debugf(format string, v ...interface{}) {
	if macaron.Env != macaron.DEV {
		return
	}
	writef(DEBUG, format, v...)
}

func Info(v ...interface{}) {
	write(INFO, v)
}

func Infof(format string, v ...interface{}) {
	writef(INFO, format, v...)
}

func Warn(v ...interface{}) {
	write(WARN, v)
}

func Warnf(format string, v ...interface{}) {
	writef(WARN, format, v...)
}

func Error(v ...interface{}) {
	write(ERROR, v)
}

func Errorf(format string, v ...interface{}) {
	writef(ERROR, format, v...)
}

func Fatal(v ...interface{}) {
	write(FATAL, v)
}

func Fatalf(format string, v ...interface{}) {
	writef(FATAL, format, v...)
}

func write(level Level, v ...interface{}) {
	if logger == nil {
		// 如果logger尚未初始化，直接打印到标准错误
		fmt.Fprintf(os.Stderr, "Logger not initialized yet: %v\n", v)
		if level == FATAL {
			os.Exit(1)
		}
		return
	}
	
	defer logger.Flush()

	content := ""
	if macaron.Env == macaron.DEV {
		pc, file, line, ok := runtime.Caller(2)
		if ok {
			content = fmt.Sprintf("#%s#%s#%d行#", file, runtime.FuncForPC(pc).Name(), line)
		}
	}

	switch level {
	case DEBUG:
		logger.Debug(content, v)
	case INFO:
		logger.Info(content, v)
	case WARN:
		logger.Warn(content, v)
	case FATAL:
		logger.Critical(content, v)
		os.Exit(1)
	case ERROR:
		logger.Error(content, v)
	}
}

func writef(level Level, format string, v ...interface{}) {
	if logger == nil {
		// 如果logger尚未初始化，直接打印到标准错误
		fmt.Fprintf(os.Stderr, "Logger not initialized yet: %s %v\n", format, v)
		if level == FATAL {
			os.Exit(1)
		}
		return
	}
	
	defer logger.Flush()

	content := ""
	if macaron.Env == macaron.DEV {
		pc, file, line, ok := runtime.Caller(2)
		if ok {
			content = fmt.Sprintf("#%s#%s#%d行#", file, runtime.FuncForPC(pc).Name(), line)
		}
	}

	format = content + format

	switch level {
	case DEBUG:
		logger.Debugf(format, v...)
	case INFO:
		logger.Infof(format, v...)
	case WARN:
		logger.Warnf(format, v...)
	case FATAL:
		logger.Criticalf(format, v...)
		os.Exit(1)
	case ERROR:
		logger.Errorf(format, v...)
	}
}

func getLogConfig() string {
	var logPath string
	
	// 优先使用命令行参数指定的日志路径
	if CommandLogPath != "" {
		logPath = CommandLogPath
	} else {
		// 尝试从系统进程环境判断是否为系统服务
		isSystemService := false
		// 简单判断：当前用户为root或使用了系统配置路径，则认为是系统服务
		if os.Getuid() == 0 || len(os.Getenv("GOCRON_CONFIG_PATH")) > 0 || CommandConfigPath != "" {
			isSystemService = true
		}

		if isSystemService {
			logPath = "/var/log/gocron/cron.log"
		} else {
			logPath = "log/cron.log"
		}
	}

	// 确保日志目录存在
	logDir := filepath.Dir(logPath)
	if err := os.MkdirAll(logDir, 0755); err != nil {
		fmt.Fprintf(os.Stderr, "创建日志目录失败: %v\n", err)
		// 使用当前目录作为备用方案
		logPath = "log/cron.log"
		logDir = "log"
		_ = os.MkdirAll(logDir, 0755)
	}

	config := `
    <seelog>
        <outputs formatid="main">
            %s
            <filter levels="info,critical,error,warn">
                <rollingfile type="date" filename="%s" datepattern="2006-01-02" maxrolls="7" />
            </filter>
        </outputs>
        <formats>
            <format id="main" format="%%Date/%%Time [%%LEV] %%Msg%%n"/>
        </formats>
    </seelog>`

	consoleConfig := ""
	if macaron.Env == macaron.DEV {
		consoleConfig =
			`
            <filter levels="info,debug,critical,warn,error">
                <console />
            </filter>
         `
	}

	config = fmt.Sprintf(config, consoleConfig, logPath)

	return config
}
