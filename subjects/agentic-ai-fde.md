### 1. 에이전트 프레임워크 및 설계 능력 (Core Agentic AI)
AI가 스스로 도구를 쓰고, 판단하고, 루프를 돌며 문제를 해결하게 만드는 아키텍처를 깊게 이해해야 합니다.
* 프레임워크 숙달: **LangGraph(랭그래프)**와 LlamaIndex(Workflows) 같은 상태 중심(Stateful) 에이전트 프레임워크의 핵심 메커니즘.
* 디자인 패턴: Plan-and-Solve(계획 후 실행), ReAct(이유 찾기 및 행동), Reflection(자기 비판/수정), Multi-Agent(여러 AI 간의 협업) 패턴을 자유자재로 구현할 수 있어야 합니다.
* 제어 흐름 설계: AI가 뫼비우스의 띠처럼 무한 루프에 빠지지 않도록 조건부 분기(Conditional Edges)와 휴먼 인 더 루프(Human-in-the-loop) 승인 절차를 설계하는 능력.

### 2. 상태(State) 및 영속성 관리 (Backend & Infra)
앞서 질문하셨던 것처럼, 에이전트는 일반 웹앱보다 훨씬 복잡한 메모리 상태를 가집니다. 이를 안정적으로 서빙하는 인프라 지식이 필수적입니다.
* 상태 직렬화 및 동기화: 에이전트의 복잡한 실행 상태(State Snapshot)를 분산 환경에서 어떻게 유지할 것인가?
* 분산 체크포인팅: 분산 서버 환경에서 데이터 유실 없이 상태를 관리하기 위한 Redis(캐싱/속도) 및 PostgreSQL/MongoDB(영속성/안정성) 아키텍처 설계.
* 비동기 큐 & 이벤트 기반 처리: AI의 연산은 시간이 오래 걸리므로, Celery나 Kafka 같은 메시지 큐를 이용해 백그라운드에서 비동기로 에이전트를 돌리는 구조(Event-driven) 이해.

### 3. 엔터프라이즈 데이터 연동 (Data & RAG)
AI가 똑똑하려면 기업 내부 데이터나 외부 정보를 정확하게 가져와야 합니다.
* 고급 RAG (Advanced RAG): 단순 텍스트 검색을 넘어, 에이전트가 스스로 검색 쿼리를 수정(Query Rewriting)하고, 검색 결과를 평가(Reranking)하여 필요한 정보만 쏙쏙 뽑아 쓰게 만드는 기술.
* 벡터 데이터베이스 (Vector DB): Pinecone, Milvus, Chroma, pgvector 등의 특징을 이해하고 대규모 임베딩 데이터를 효율적으로 검색·관리하는 방법.
* 도구 연동 (Tool Use/Function Calling): 사내 데이터베이스(SQL), 외부 API(Slack, Notion, Google 검색 등)를 AI가 안전하고 정확하게 호출할 수 있도록 인포매틱스 포맷(JSON 스키마)을 설계하는 능력.

### 4. 모니터링, 평가 및 프론트엔드 연동 (LLMOps & Frontend)
개발한 에이전트 시스템을 사용자에게 안전하게 서빙하고 유지보수하는 영역입니다.
* 에이전트 모니터링: AI가 내부적으로 어떤 노드를 거쳐 왜 이런 답변을 냈는지 추적(Tracing)하는 도구(LangSmith, Arize Phoenix 등) 활용법.
* 비용 및 레이턴시 최적화: 프롬프트 토큰 소모량을 줄이고, 느린 LLM 응답 속도를 극복하기 위한 스트리밍(Streaming) 데이터 처리.
* 실시간 UI 연동: 에이전트가 뒤에서 생각하고 행동하는 과정을 사용자 화면에 실시간으로 실감 나게 보여주는 웹소켓(WebSocket) 또는 SSE(Server-Sent Events) 통신 구현 (Next.js, FastAPI 등과의 연동).
