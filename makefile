# 开启 Go 模块支持
GO111MODULE=on

# 构建目标：编译生成 gocron 主服务和 gocron-node 节点服务
.PHONY: build
build: gocron node

# 构建目标：启用竞态检测的构建（用于检测并发冲突）
.PHONY: build-race
build-race: enable-race build

# 运行目标：构建后运行服务
.PHONY: run
run: build kill
	./bin/gocron-node &
	./bin/gocron web -e dev

# 运行目标：启用竞态检测的方式运行
.PHONY: run-race
run-race: enable-race run

# 清理目标：杀死所有gocron-node进程
.PHONY: kill
kill:
	-killall gocron-node

# 构建gocron主服务程序
.PHONY: gocron
gocron:
	go build $(RACE) -o bin/gocron ./cmd/gocron

# 构建gocron节点服务程序
.PHONY: node
node:
	go build $(RACE) -o bin/gocron-node ./cmd/node

# 执行单元测试
.PHONY: test
test:
	go test $(RACE) ./...

# 执行单元测试并检测竞态条件
.PHONY: test-race
test-race: enable-race test

# 启用竞态检测标记
.PHONY: enable-race
enable-race:
	$(eval RACE = -race)

# 项目打包：构建Vue前端，生成静态资源并执行打包脚本
.PHONY: package
package: build-vue statik
	bash ./package.sh

# 打包到所有平台（linux, darwin, windows）
.PHONY: package-all
package-all: build-vue statik
	bash ./package.sh -p 'linux darwin windows'

# 构建Vue前端项目（构建生产版本并复制到公有目录）
.PHONY: build-vue
build-vue:
	cd web/vue && yarn run build
	rm -rf web/public/*
	cp -r web/vue/dist/* web/public/

# 安装Vue前端项目依赖
.PHONY: install-vue
install-vue:
	cd web/vue && yarn install

# 运行Vue前端开发服务器
.PHONY: run-vue
run-vue:
	cd web/vue && yarn run dev

# 使用statik工具将静态资源嵌入到Go二进制文件中
.PHONY: statik
statik:
	go get github.com/rakyll/statik
	go generate ./...

# 运行代码质量检查工具
.PHONY: lint
	golangci-lint run

# 生成deb包 - gocron-web (仅web管理界面服务)
.PHONY: deb-web
deb-web: gocron
	bash ./build-web-deb.sh $(version)

# 生成deb包 - gocron-node (仅node执行服务)
.PHONY: deb-node
deb-node: node
	bash ./build-node-deb.sh $(version)

# 生成所有deb包 (web包 + node包)
.PHONY: deb-all
deb-all: build
	bash ./build-web-deb.sh $(version)
	bash ./build-node-deb.sh $(version)

.PHONY: deb
deb: deb-web

# 生成RPM包 - gocron-web (仅web管理界面服务)
.PHONY: rpm-web
rpm-web: gocron
	bash ./build-web-rpm.sh $(version)

# 生成RPM包 - gocron-node (仅node执行服务)
.PHONY: rpm-node
rpm-node: node
	bash ./build-node-rpm.sh $(version)

# 生成所有RPM包 (web包 + node包)
.PHONY: rpm-all
rpm-all: build
	bash ./build-web-rpm.sh $(version)
	bash ./build-node-rpm.sh $(version)

.PHONY: rpm
rpm: rpm-web

# 清理生成的可执行文件
.PHONY: clean
clean:
	rm -f bin/gocron
	rm -f bin/gocron-node
	rm -rf pkg/
	rm -rf web/public/*
