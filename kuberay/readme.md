엔드투엔드 목차 (전처리 → 훈련)

섹션	내용	엮이는 AWS 서비스

1. 배경/과제	우리 ML 워크로드의 규모·문제 (비용, 스케일, 운영 부담)	— (고객 사례의 정당성)

2. 왜 이 아키텍처인가	"왜 그냥 SageMaker Training Job이 아니라 EKS+Ray인가" 명시	EKS 정당성 확보

3. 기반	클러스터 구성, GPU 노드 자동 스케일	EKS + Karpenter + EC2 P5/G6

4. 데이터 전처리	Ray Data로 대규모 배치 전처리, Spot으로 비용 절감	S3 + Mountpoint / Spot

5. GPU 훈련	같은 Ray 클러스터에서 멀티노드 훈련	SageMaker HyperPod (EKS+Ray) + EFA

6. 관측성/운영	Ray Dashboard 메트릭 수집	Managed Prometheus + Grafana

7. 결과	비용/시간/스케일 개선 수치 (정량 지표 필수)
