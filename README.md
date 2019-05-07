# salt-master-minion-api
维护一个以centos官方镜像为基础的salt测试环境, 包含salt-master、salt-minion、salt-api

### 构建命令
docker build -t tgyday/salt-master-minion-api .

### 运行
docker run -p 4505:4505 -p 4506:4506 -p 8000:8000 -d -it tgyday/salt-master-minion-api

### 测试 salt api
curl -sSk 'https://127.0.0.1:8000/login' -H 'Accept: application/x-yaml' -d username=saltapi -d password=123456 -d eauth=pam
