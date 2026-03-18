package notify

import (
	"html"
	"time"
	"strings"
	"encoding/json"
	"fmt"

	"github.com/ouqiang/gocron/internal/models"
	"github.com/ouqiang/gocron/internal/modules/httpclient"
	"github.com/ouqiang/gocron/internal/modules/logger"
	"github.com/ouqiang/gocron/internal/modules/utils"
)

type WebHook struct{}

func (webHook *WebHook) Send(msg Message) {
	model := new(models.Setting)
	webHookSetting, err := model.Webhook()
	if err != nil {
		logger.Error("#webHook#从数据库获取webHook配置失败", err)
		return
	}
	if webHookSetting.Url == "" {
		logger.Error("#webHook#webhook-url为空")
		return
	}
	logger.Debugf("%+v", webHookSetting)
	msg["name"] = utils.EscapeJson(msg["name"].(string))
	msg["output"] = utils.EscapeJson(msg["output"].(string))
	msg["content"] = parseNotifyTemplate(webHookSetting.Template, msg)
	msg["content"] = html.UnescapeString(msg["content"].(string))
	webHook.send(msg, webHookSetting.Url)
}

func (webHook *WebHook) send(msg Message, url string) {
	content := msg["content"].(string)
	
	// 检测webhook地址是否为飞书机器人链接
	isFeishuWebhook := strings.Contains(url, "feishu.cn") || strings.Contains(url, "larksuite.com")
	
	if isFeishuWebhook {
		// 对于飞书webhook进行特殊格式处理
		content = formatForFeishuBot(content)
	} else {
		// 对于一般webhook，使用原始格式发送
		// 不需要修改内容，按原来方式发送
	}
	
	timeout := 30
	maxTimes := 3
	i := 0
	for i < maxTimes {
		resp := httpclient.PostJson(url, content, timeout)
		if resp.StatusCode == 200 {
			logger.Debugf("webHook#发送消息成功#响应-%s", resp.Body)
			break
		}
		i += 1
		time.Sleep(2 * time.Second)
		if i < maxTimes {
			logger.Errorf("webHook#发送消息失败#%s#消息内容-%s", resp.Body, content)
		}
	}
}

// 格式化内容以适配飞书机器人
func formatForFeishuBot(content string) string {
	var dataMap map[string]interface{}
	err := json.Unmarshal([]byte(content), &dataMap)
	if err != nil {
		logger.Errorf("webHook#JSON解析失败#%s#消息内容-%s", err.Error(), content)
		
		// 构造基础文本消息
		formattedContent := map[string]interface{}{
			"msg_type": "text",
			"content": map[string]string{
				"text": "任务通知: " + content,
			},
		}
		contentBytes, _ := json.Marshal(formattedContent)
		return string(contentBytes)
	} else {
		// 解析数据并构造适合飞书显示的文本
		originalContent := ""
		if result, exists := dataMap["result"]; exists {
			originalContent = result.(string)
		} else {
			originalContent = content
		}
		
		text := constructFeishuText(dataMap, originalContent)
		formattedContent := map[string]interface{}{
			"msg_type": "text",
			"content": map[string]string{
				"text": text,
			},
		}
		contentBytes, _ := json.Marshal(formattedContent)
		return string(contentBytes)
	}
}

func constructFeishuText(dataMap map[string]interface{}, result string) string {
	taskInfo := "任务执行情况:\n"
	if taskName, exists := dataMap["task_name"]; exists {
		taskInfo += "任务名称: " + toString(taskName) + "\n"
	}
	if status, exists := dataMap["status"]; exists {
		taskInfo += "执行状态: " + toString(status) + "\n"
	}
	if taskId, exists := dataMap["task_id"]; exists {
		taskInfo += "任务ID: " + toString(taskId) + "\n"
	}
	if remark, exists := dataMap["remark"]; exists && toString(remark) != "" {
		taskInfo += "备注: " + toString(remark) + "\n"
	}
	taskInfo += "\n输出详情:\n" + result
	return taskInfo
}

func toString(value interface{}) string {
	switch v := value.(type) {
	case string:
		return v
	case int:
		return fmt.Sprintf("%d", v)
	case int64:
		return fmt.Sprintf("%d", v)
	case float64:
		return fmt.Sprintf("%g", v)
	default:
		return ""
	}
}
