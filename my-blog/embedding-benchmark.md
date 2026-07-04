## BAAI/bge-m3 모델의 인프라 벤치마크 ##
이 모델은 일반적인 BERT(768차원)와 달리 1024차원 고밀도 벡터를 사용하고 최대 8192 토큰까지 지원하므로, 컨텍스트가 길어질수록 메모리 대역폭 싸움이 치열해진다.
따라서 벤치마크를 설계할 때 `단순 질문(짧은 문장)`과 `RAG 문서(긴 문장)` 두 가지 케이스를 모두 검증해야 정확한 스코어가 나온다.
구체적인 벤치마크 환경 구성 및 파이썬 검증 코드는 다음과 같다.

### 1. 벤치마크 환경 통제 (Fair 시나리오) ###
두 인스턴스의 하드웨어가 완벽히 동등한 조건에서 일대일 대결을 하도록 통제해야 합니다.
*	인스턴스 스펙 맞추기:
  * c6i.xlarge (4 vCPU / 8 GiB RAM / Intel Xeon)
  * c7g.xlarge (4 vCPU / 8 GiB RAM / AWS Graviton 3)
*	OS 및 런타임:
  * Ubuntu 22.04 LTS 혹은 Amazon Linux 2023 (aarch64용과 x86_64용 최신 OS)
*	Python 3.10+ 환경 및 동일한 버전의 sentence-transformers 라이브러리 사용
* 임베딩 엔진 라이브러리:
  * CPU 연산 속도를 극대화하기 위해 오픈소스 추론 엔진인 ONNX Runtime 기법을 쓰거나, PyTorch 환경에서 최신 CPU 가속 라이브러리(ipex 등)가 켜졌는지 점검해야 하지만, 첫 테스트는 순수 PyTorch CPU 모드로 먼저 일대일 비교를 진행합니다.

### 2. 실전 벤치마크 스크립트 (Python) ###
두 서버에 각각 아래 코드를 올린 뒤 실행하여 **"초당 몇 개의 문장을 처리하는지(Throughput)"**와 **"문장 1개당 몇 ms가 걸리는지(Latency)"**를 측정합니다.
```
import time
import numpy as np
from sentence_transformers import SentenceTransformer

# 1. BGE-M3 모델 로드 (CPU 명시)
print("Loading BAAI/bge-m3 model on CPU...")
model = SentenceTransformer('BAAI/bge-m3', device='cpu')

# 2. 더미 데이터 세팅 (실전 시나리오 반영)
# 시나리오 A: 유저가 던지는 짧은 검색 쿼리 (평균 15단어)
short_texts = ["최신 AWS 그라비톤 프로세서의 L3 캐시 메모리 아키텍처와 대역폭 효율성 조사"] * 100

# 시나리오 B: RAG 엔진에 들어갈 긴 컨텍스트 문서 조각 (평균 300단어)
long_text_chunk = """
AWS Graviton3 프로세서는 클라우드 워크로드를 위해 Amazon에서 맞춤 설계한 64비트 ARM 기반 칩셋입니다. 
기존 2세대 그라비톤에 비해 뛰어난 컴퓨터 연산 성능과 2배 더 넓은 DDR5 메모리 대역폭을 제공합니다. 
특히 대규모 트랜스포머 기반 임베딩 연산 시, 수많은 물리 코어가 격자 구조(Mesh Network)로 연결되어 
L3 캐시 풀에 균일하고 빠르게 접근할 수 있어 인덱싱 작업의 병목을 크게 해소합니다. 
하이퍼스레딩 없이 독립된 물리 코어 성능을 보장하므로 자바 가상 머신(JVM)의 가비지 컬렉션(GC) 성능 및 
문장 임베딩 벡터 생성 시 일관된 꼬리 지연 시간(Tail Latency) 보장에 압도적인 효율을 자랑합니다.
"""
long_texts = [long_text_chunk] * 50  # 연산량이 크므로 50개만 진행

def run_benchmark(name, text_list, batch_size=1):
    print(f"\n=== {name} 벤치마크 시작 (Batch Size: {batch_size}) ===")
    
    # 워밍업 (Warming up: 초기에 캐시나 라이브러리 로드 시간 제외 목적)
    model.encode(text_list[:2], batch_size=batch_size, normalize_embeddings=True)
    
    # 본 측정
    start_time = time.perf_counter()
    embeddings = model.encode(text_list, batch_size=batch_size, normalize_embeddings=True)
    end_time = time.perf_counter()
    
    total_time = end_time - start_time
    avg_latency = (total_time / len(text_list)) * 1000 # ms 단위
    throughput = len(text_list) / total_time
    
    print(f"총 소요 시간: {total_time:.4f} 초")
    print(f"문장 1개당 평균 지연 시간(Latency): {avg_latency:.2f} ms")
    print(f"초당 처리 문장 수(Throughput): {throughput:.2f} sentences/sec")
    return avg_latency, throughput

# 실행 (배치 크기를 1과 8로 각각 테스트하여 하드웨어 효율 측정)
run_benchmark("짧은 문장 쿼리 (Batch 1)", short_texts, batch_size=1)
run_benchmark("짧은 문장 쿼리 (Batch 8)", short_texts, batch_size=8)
run_benchmark("긴 문서 청크 (Batch 1)", long_texts, batch_size=1)
run_benchmark("긴 문서 청크 (Batch 8)", long_texts, batch_size=8)
```

### 3. 결과 분석 및 '가성비(Price-Performance)' ###
실험이 끝나면 단순히 속도만 보면 안 되고, **"1달러당 누가 더 많은 벡터를 구워냈는가"**를 계산해야 완벽한 기술 블로그 소스가 완성됩니다.
각 서버의 출력창에 나온 Throughput (초당 처리량) 수치를 기반으로 아래 계산식을 대입합니다.
‭$$\text{달러당 처리량} = \frac{\text{초당 처리 문장 수 (Throughput)} \times 3600}{\text{인스턴스 시간당 비용 (On-Demand Cost)}}$$‬‭‬

#### 📊 예상되는 결과 포인트 (관전 포인트) ####

1.	`짧은 문장 (Batch 1)`: 인텔 제온의 '싱글 코어 높은 깡클럭' 덕분에 c6i가 아주 미세하게 레이턴시가 앞서거나 비등할 수 있습니다.
2.	`긴 문서 청크 + Batch 8`: BAAI/bge-m3가 1024차원의 행렬과 토큰을 쏟아내며 메모리를 풀로 당기기 시작하면, DDR5 대역폭과 물리 코어를 독점하는 그라비톤3(c7g)이 초당 처리량(Throughput)에서 인텔을 추월하기 시작합니다.
3.	`가성비(Price-Performance)`: c7g 인스턴스가 인텔에 비해 기본 단가 자체가 약 15~17% 저렴하기 때문에, 달러당 처리량(성능비) 측면에서는 그라비톤이 최종 판정승을 거둘 확률이 매우 높습니다.
두 인스턴스에 위 스크립트를 돌려 나온 로그 스크린샷과 가성비 변환 테이블을 나란히 배치하면, 사내 보고서나 기술 블로그에서 최고의 설득력을 갖춘 데이터가 될 것입니다!
