#!/bin/bash

# ================= 설정 변수 =================
# AWS 서울 리전 지정
REGION="ap-northeast-2"

# AWS에 등록된 본인의 EC2 키페어 이름 입력
KEY_NAME="my-macbook-key"

# 인텔(x86) 전용 고성능 인스턴스 타입 지정
INSTANCE_TYPE="c6i.2xlarge"
# =============================================

echo "🔍 [1단계] 서울 리전($REGION)의 최신 Amazon Linux 2023 (x86_64) AMI ID를 조회합니다..."

# AWS SSM Parameter Store에서 AL2023 x86_64 아키텍처용 최신 AMI ID 추출
AMI_ID=$(aws ssm get-parameters \
    --names "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" \
    --region "$REGION" \
    --query "Parameters[0].Value" \
    --output text)

if [ -z "$AMI_ID" ] || [ "$AMI_ID" == "None" ]; then
    echo "❌ AMI ID를 조회하는데 실패했습니다. AWS CLI 로그인 상태나 권한을 확인해주세요."
    exit 1
fi

echo "🎯 확인된 최신 AMI ID: $AMI_ID"
echo "🚀 [2단계] 기본 VPC에 인스턴스 생성을 시작합니다..."

# EC2 인스턴스 생성 명령어 실행
INSTANCE_INFO=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --region "$REGION" \
    --associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Graviton-Bench-x86}]" \
    --output json)

# 생성된 인스턴스의 ID 추출
INSTANCE_ID=$(echo "$INSTANCE_INFO" | grep -o '"InstanceId": "[^"]*' | grep -o '[^"]*$')

echo "⏳ 인스턴스가 생성되었습니다. (ID: $INSTANCE_ID)"
echo "📡 퍼블릭 IP 주소가 할당될 때까지 잠시 대기합니다..."

# 인스턴스가 실행(running) 상태로 완전히 바뀔 때까지 대기
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

# 할당된 퍼블릭 IP 주소 추출
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

echo "--------------------------------------------------"
echo "✅ Amazon Linux 2023 인스턴스 생성 완료!"
echo "📌 인스턴스 ID : $INSTANCE_ID"
echo "🌐 퍼블릭 IP   : $PUBLIC_IP"
echo "💡 접속 명령어 : ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo "--------------------------------------------------"
