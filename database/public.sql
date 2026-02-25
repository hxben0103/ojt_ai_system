/*
 Navicat Premium Data Transfer

 Source Server         : log_in
 Source Server Type    : PostgreSQL
 Source Server Version : 170004 (170004)
 Source Host           : localhost:5432
 Source Catalog        : ojt_ai_system
 Source Schema         : public

 Target Server Type    : PostgreSQL
 Target Server Version : 170004 (170004)
 File Encoding         : 65001

 Date: 28/11/2025 20:37:53
*/


-- ----------------------------
-- Sequence structure for ai_insights_insight_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."ai_insights_insight_id_seq";
CREATE SEQUENCE "public"."ai_insights_insight_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for attendance_attendance_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."attendance_attendance_id_seq";
CREATE SEQUENCE "public"."attendance_attendance_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for chatbot_logs_chat_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."chatbot_logs_chat_id_seq";
CREATE SEQUENCE "public"."chatbot_logs_chat_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for evaluations_eval_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."evaluations_eval_id_seq";
CREATE SEQUENCE "public"."evaluations_eval_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for ojt_records_record_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."ojt_records_record_id_seq";
CREATE SEQUENCE "public"."ojt_records_record_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for system_reports_report_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."system_reports_report_id_seq";
CREATE SEQUENCE "public"."system_reports_report_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Sequence structure for users_user_id_seq
-- ----------------------------
DROP SEQUENCE IF EXISTS "public"."users_user_id_seq";
CREATE SEQUENCE "public"."users_user_id_seq" 
INCREMENT 1
MINVALUE  1
MAXVALUE 2147483647
START 1
CACHE 1;

-- ----------------------------
-- Table structure for ai_insights
-- ----------------------------
DROP TABLE IF EXISTS "public"."ai_insights";
CREATE TABLE "public"."ai_insights" (
  "insight_id" int4 NOT NULL DEFAULT nextval('ai_insights_insight_id_seq'::regclass),
  "student_id" int4 NOT NULL,
  "model_name" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "insight_type" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "result" jsonb NOT NULL,
  "confidence" numeric(4,2),
  "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "input_data" jsonb,
  "model_version" varchar(20) COLLATE "pg_catalog"."default",
  "processing_time_ms" int4
)
;

-- ----------------------------
-- Records of ai_insights
-- ----------------------------
INSERT INTO "public"."ai_insights" VALUES (2, 10, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30698290395714967, "class_probabilities": {"A": 0.30698290395714967, "B": 0.19025846783051445, "C": 0.09652178100699565, "D": 0.2333235477708944, "F": 0.17291329943444533}}', 0.31, '2025-11-24 04:23:16.148501', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 144, "attendance_today_hours": 0, "attendance_days_present": 18}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (3, 8, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.29916693353477314, "class_probabilities": {"A": 0.29916693353477314, "B": 0.18938282054564856, "C": 0.09351474530530039, "D": 0.24427755843348198, "F": 0.17365794218079506}}', 0.30, '2025-11-24 04:23:18.304298', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 70.25, "attendance_today_hours": 0, "attendance_days_present": 10}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (4, 7, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.3140151849154871, "class_probabilities": {"A": 0.3140151849154871, "B": 0.19103280629870065, "C": 0.0995105906329524, "D": 0.2231681204926321, "F": 0.17227329766022648}}', 0.31, '2025-11-24 04:23:20.434619', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 208, "attendance_today_hours": 0, "attendance_days_present": 26}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (5, 6, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30881687909161915, "class_probabilities": {"A": 0.30881687909161915, "B": 0.19046137788840325, "C": 0.09727167781724326, "D": 0.23070516270091246, "F": 0.1727449025018231}}', 0.31, '2025-11-24 04:23:22.586369', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 159.75, "attendance_today_hours": 0, "attendance_days_present": 20}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (6, 9, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30414017661107184, "class_probabilities": {"A": 0.30414017661107184, "B": 0.18994220727076103, "C": 0.09539491243432806, "D": 0.2373444815811446, "F": 0.17317822210269465}}', 0.30, '2025-11-24 04:23:24.70905', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 120, "attendance_today_hours": 0, "attendance_days_present": 15}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (7, 10, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30698290395714967, "class_probabilities": {"A": 0.30698290395714967, "B": 0.19025846783051445, "C": 0.09652178100699565, "D": 0.2333235477708944, "F": 0.17291329943444533}}', 0.31, '2025-11-24 04:37:37.041853', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 144, "attendance_today_hours": 0, "attendance_days_present": 18}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (8, 8, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.29916693353477314, "class_probabilities": {"A": 0.29916693353477314, "B": 0.18938282054564856, "C": 0.09351474530530039, "D": 0.24427755843348198, "F": 0.17365794218079506}}', 0.30, '2025-11-24 04:37:39.264588', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 70.25, "attendance_today_hours": 0, "attendance_days_present": 10}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (9, 7, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.3140151849154871, "class_probabilities": {"A": 0.3140151849154871, "B": 0.19103280629870065, "C": 0.0995105906329524, "D": 0.2231681204926321, "F": 0.17227329766022648}}', 0.31, '2025-11-24 04:37:41.393374', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 208, "attendance_today_hours": 0, "attendance_days_present": 26}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (10, 6, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30881687909161915, "class_probabilities": {"A": 0.30881687909161915, "B": 0.19046137788840325, "C": 0.09727167781724326, "D": 0.23070516270091246, "F": 0.1727449025018231}}', 0.31, '2025-11-24 04:37:43.507336', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 159.75, "attendance_today_hours": 0, "attendance_days_present": 20}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (11, 9, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30414017661107184, "class_probabilities": {"A": 0.30414017661107184, "B": 0.18994220727076103, "C": 0.09539491243432806, "D": 0.2373444815811446, "F": 0.17317822210269465}}', 0.30, '2025-11-24 04:37:45.698191', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 120, "attendance_today_hours": 0, "attendance_days_present": 15}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (12, 10, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30698290395714967, "class_probabilities": {"A": 0.30698290395714967, "B": 0.19025846783051445, "C": 0.09652178100699565, "D": 0.2333235477708944, "F": 0.17291329943444533}}', 0.31, '2025-11-24 05:01:16.601426', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 144, "attendance_today_hours": 0, "attendance_days_present": 18}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (13, 8, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.29916693353477314, "class_probabilities": {"A": 0.29916693353477314, "B": 0.18938282054564856, "C": 0.09351474530530039, "D": 0.24427755843348198, "F": 0.17365794218079506}}', 0.30, '2025-11-24 05:01:18.723033', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 70.25, "attendance_today_hours": 0, "attendance_days_present": 10}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (14, 7, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.3140151849154871, "class_probabilities": {"A": 0.3140151849154871, "B": 0.19103280629870065, "C": 0.0995105906329524, "D": 0.2231681204926321, "F": 0.17227329766022648}}', 0.31, '2025-11-24 05:01:20.86428', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 208, "attendance_today_hours": 0, "attendance_days_present": 26}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (15, 6, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30881687909161915, "class_probabilities": {"A": 0.30881687909161915, "B": 0.19046137788840325, "C": 0.09727167781724326, "D": 0.23070516270091246, "F": 0.1727449025018231}}', 0.31, '2025-11-24 05:01:23.000082', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 159.75, "attendance_today_hours": 0, "attendance_days_present": 20}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (16, 9, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30414017661107184, "class_probabilities": {"A": 0.30414017661107184, "B": 0.18994220727076103, "C": 0.09539491243432806, "D": 0.2373444815811446, "F": 0.17317822210269465}}', 0.30, '2025-11-24 05:01:25.104878', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 120, "attendance_today_hours": 0, "attendance_days_present": 15}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (17, 10, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30698290395714967, "class_probabilities": {"A": 0.30698290395714967, "B": 0.19025846783051445, "C": 0.09652178100699565, "D": 0.2333235477708944, "F": 0.17291329943444533}}', 0.31, '2025-11-24 06:22:09.32955', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 144, "attendance_today_hours": 0, "attendance_days_present": 18}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (18, 8, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.29916693353477314, "class_probabilities": {"A": 0.29916693353477314, "B": 0.18938282054564856, "C": 0.09351474530530039, "D": 0.24427755843348198, "F": 0.17365794218079506}}', 0.30, '2025-11-24 06:22:11.471221', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 70.25, "attendance_today_hours": 0, "attendance_days_present": 10}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (19, 7, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.3140151849154871, "class_probabilities": {"A": 0.3140151849154871, "B": 0.19103280629870065, "C": 0.0995105906329524, "D": 0.2231681204926321, "F": 0.17227329766022648}}', 0.31, '2025-11-24 06:22:13.663403', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 208, "attendance_today_hours": 0, "attendance_days_present": 26}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (20, 6, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30881687909161915, "class_probabilities": {"A": 0.30881687909161915, "B": 0.19046137788840325, "C": 0.09727167781724326, "D": 0.23070516270091246, "F": 0.1727449025018231}}', 0.31, '2025-11-24 06:22:15.783285', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 159.75, "attendance_today_hours": 0, "attendance_days_present": 20}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (21, 9, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30414017661107184, "class_probabilities": {"A": 0.30414017661107184, "B": 0.18994220727076103, "C": 0.09539491243432806, "D": 0.2373444815811446, "F": 0.17317822210269465}}', 0.30, '2025-11-24 06:22:17.899992', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 120, "attendance_today_hours": 0, "attendance_days_present": 15}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (22, 10, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30698290395714967, "class_probabilities": {"A": 0.30698290395714967, "B": 0.19025846783051445, "C": 0.09652178100699565, "D": 0.2333235477708944, "F": 0.17291329943444533}}', 0.31, '2025-11-27 03:58:54.853353', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 144, "attendance_today_hours": 0, "attendance_days_present": 18}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (23, 8, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.29916693353477314, "class_probabilities": {"A": 0.29916693353477314, "B": 0.18938282054564856, "C": 0.09351474530530039, "D": 0.24427755843348198, "F": 0.17365794218079506}}', 0.30, '2025-11-27 03:58:56.996067', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 70.25, "attendance_today_hours": 0, "attendance_days_present": 10}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (24, 7, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.3140151849154871, "class_probabilities": {"A": 0.3140151849154871, "B": 0.19103280629870065, "C": 0.0995105906329524, "D": 0.2231681204926321, "F": 0.17227329766022648}}', 0.31, '2025-11-27 03:58:59.129464', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 208, "attendance_today_hours": 0, "attendance_days_present": 26}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (25, 6, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30881687909161915, "class_probabilities": {"A": 0.30881687909161915, "B": 0.19046137788840325, "C": 0.09727167781724326, "D": 0.23070516270091246, "F": 0.1727449025018231}}', 0.31, '2025-11-27 03:59:01.258124', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 159.75, "attendance_today_hours": 0, "attendance_days_present": 20}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (26, 9, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30414017661107184, "class_probabilities": {"A": 0.30414017661107184, "B": 0.18994220727076103, "C": 0.09539491243432806, "D": 0.2373444815811446, "F": 0.17317822210269465}}', 0.30, '2025-11-27 03:59:03.353853', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 120, "attendance_today_hours": 0, "attendance_days_present": 15}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (27, 10, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30698290395714967, "class_probabilities": {"A": 0.30698290395714967, "B": 0.19025846783051445, "C": 0.09652178100699565, "D": 0.2333235477708944, "F": 0.17291329943444533}}', 0.31, '2025-11-27 09:13:41.468772', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 144, "attendance_today_hours": 0, "attendance_days_present": 18}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (28, 8, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.29916693353477314, "class_probabilities": {"A": 0.29916693353477314, "B": 0.18938282054564856, "C": 0.09351474530530039, "D": 0.24427755843348198, "F": 0.17365794218079506}}', 0.30, '2025-11-27 09:13:43.587394', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 70.25, "attendance_today_hours": 0, "attendance_days_present": 10}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (29, 7, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.3140151849154871, "class_probabilities": {"A": 0.3140151849154871, "B": 0.19103280629870065, "C": 0.0995105906329524, "D": 0.2231681204926321, "F": 0.17227329766022648}}', 0.31, '2025-11-27 09:13:45.730651', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 208, "attendance_today_hours": 0, "attendance_days_present": 26}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (30, 6, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30881687909161915, "class_probabilities": {"A": 0.30881687909161915, "B": 0.19046137788840325, "C": 0.09727167781724326, "D": 0.23070516270091246, "F": 0.1727449025018231}}', 0.31, '2025-11-27 09:13:47.87618', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 159.75, "attendance_today_hours": 0, "attendance_days_present": 20}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (31, 9, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30414017661107184, "class_probabilities": {"A": 0.30414017661107184, "B": 0.18994220727076103, "C": 0.09539491243432806, "D": 0.2373444815811446, "F": 0.17317822210269465}}', 0.30, '2025-11-27 09:13:50.006755', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 120, "attendance_today_hours": 0, "attendance_days_present": 15}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (32, 10, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30698290395714967, "class_probabilities": {"A": 0.30698290395714967, "B": 0.19025846783051445, "C": 0.09652178100699565, "D": 0.2333235477708944, "F": 0.17291329943444533}}', 0.31, '2025-11-27 09:17:10.651144', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 144, "attendance_today_hours": 0, "attendance_days_present": 18}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (33, 8, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.29916693353477314, "class_probabilities": {"A": 0.29916693353477314, "B": 0.18938282054564856, "C": 0.09351474530530039, "D": 0.24427755843348198, "F": 0.17365794218079506}}', 0.30, '2025-11-27 09:17:12.802596', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 70.25, "attendance_today_hours": 0, "attendance_days_present": 10}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (34, 7, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.3140151849154871, "class_probabilities": {"A": 0.3140151849154871, "B": 0.19103280629870065, "C": 0.0995105906329524, "D": 0.2231681204926321, "F": 0.17227329766022648}}', 0.31, '2025-11-27 09:17:14.925946', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 208, "attendance_today_hours": 0, "attendance_days_present": 26}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (35, 6, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30881687909161915, "class_probabilities": {"A": 0.30881687909161915, "B": 0.19046137788840325, "C": 0.09727167781724326, "D": 0.23070516270091246, "F": 0.1727449025018231}}', 0.31, '2025-11-27 09:17:17.078801', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 159.75, "attendance_today_hours": 0, "attendance_days_present": 20}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (36, 9, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30414017661107184, "class_probabilities": {"A": 0.30414017661107184, "B": 0.18994220727076103, "C": 0.09539491243432806, "D": 0.2373444815811446, "F": 0.17317822210269465}}', 0.30, '2025-11-27 09:17:19.197826', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 120, "attendance_today_hours": 0, "attendance_days_present": 15}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (37, 10, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30698290395714967, "class_probabilities": {"A": 0.30698290395714967, "B": 0.19025846783051445, "C": 0.09652178100699565, "D": 0.2333235477708944, "F": 0.17291329943444533}}', 0.31, '2025-11-27 13:45:19.25819', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 144, "attendance_today_hours": 0, "attendance_days_present": 18}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (38, 8, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.29916693353477314, "class_probabilities": {"A": 0.29916693353477314, "B": 0.18938282054564856, "C": 0.09351474530530039, "D": 0.24427755843348198, "F": 0.17365794218079506}}', 0.30, '2025-11-27 13:45:21.771492', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 70.25, "attendance_today_hours": 0, "attendance_days_present": 10}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (39, 7, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.3140151849154871, "class_probabilities": {"A": 0.3140151849154871, "B": 0.19103280629870065, "C": 0.0995105906329524, "D": 0.2231681204926321, "F": 0.17227329766022648}}', 0.31, '2025-11-27 13:45:24.619068', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 208, "attendance_today_hours": 0, "attendance_days_present": 26}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (40, 6, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30881687909161915, "class_probabilities": {"A": 0.30881687909161915, "B": 0.19046137788840325, "C": 0.09727167781724326, "D": 0.23070516270091246, "F": 0.1727449025018231}}', 0.31, '2025-11-27 13:45:26.953834', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 159.75, "attendance_today_hours": 0, "attendance_days_present": 20}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (41, 9, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30414017661107184, "class_probabilities": {"A": 0.30414017661107184, "B": 0.18994220727076103, "C": 0.09539491243432806, "D": 0.2373444815811446, "F": 0.17317822210269465}}', 0.30, '2025-11-27 13:45:30.053691', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 120, "attendance_today_hours": 0, "attendance_days_present": 15}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (42, 10, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30698290395714967, "class_probabilities": {"A": 0.30698290395714967, "B": 0.19025846783051445, "C": 0.09652178100699565, "D": 0.2333235477708944, "F": 0.17291329943444533}}', 0.31, '2025-11-27 16:20:47.506196', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 144, "attendance_today_hours": 0, "attendance_days_present": 18}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (43, 8, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.29916693353477314, "class_probabilities": {"A": 0.29916693353477314, "B": 0.18938282054564856, "C": 0.09351474530530039, "D": 0.24427755843348198, "F": 0.17365794218079506}}', 0.30, '2025-11-27 16:20:51.714534', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 70.25, "attendance_today_hours": 0, "attendance_days_present": 10}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (44, 7, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.3140151849154871, "class_probabilities": {"A": 0.3140151849154871, "B": 0.19103280629870065, "C": 0.0995105906329524, "D": 0.2231681204926321, "F": 0.17227329766022648}}', 0.31, '2025-11-27 16:20:55.904941', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 208, "attendance_today_hours": 0, "attendance_days_present": 26}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (45, 6, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30881687909161915, "class_probabilities": {"A": 0.30881687909161915, "B": 0.19046137788840325, "C": 0.09727167781724326, "D": 0.23070516270091246, "F": 0.1727449025018231}}', 0.31, '2025-11-27 16:21:00.137196', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 159.75, "attendance_today_hours": 0, "attendance_days_present": 20}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (46, 9, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30414017661107184, "class_probabilities": {"A": 0.30414017661107184, "B": 0.18994220727076103, "C": 0.09539491243432806, "D": 0.2373444815811446, "F": 0.17317822210269465}}', 0.30, '2025-11-27 16:21:04.327864', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 120, "attendance_today_hours": 0, "attendance_days_present": 15}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (47, 10, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30698290395714967, "class_probabilities": {"A": 0.30698290395714967, "B": 0.19025846783051445, "C": 0.09652178100699565, "D": 0.2333235477708944, "F": 0.17291329943444533}}', 0.31, '2025-11-27 16:41:27.346114', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 144, "attendance_today_hours": 0, "attendance_days_present": 18}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (48, 8, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.29916693353477314, "class_probabilities": {"A": 0.29916693353477314, "B": 0.18938282054564856, "C": 0.09351474530530039, "D": 0.24427755843348198, "F": 0.17365794218079506}}', 0.30, '2025-11-27 16:41:31.53638', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 70.25, "attendance_today_hours": 0, "attendance_days_present": 10}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (49, 7, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.3140151849154871, "class_probabilities": {"A": 0.3140151849154871, "B": 0.19103280629870065, "C": 0.0995105906329524, "D": 0.2231681204926321, "F": 0.17227329766022648}}', 0.31, '2025-11-27 16:41:36.172472', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 208, "attendance_today_hours": 0, "attendance_days_present": 26}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (50, 6, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30881687909161915, "class_probabilities": {"A": 0.30881687909161915, "B": 0.19046137788840325, "C": 0.09727167781724326, "D": 0.23070516270091246, "F": 0.1727449025018231}}', 0.31, '2025-11-27 16:41:40.318369', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 159.75, "attendance_today_hours": 0, "attendance_days_present": 20}', NULL, NULL);
INSERT INTO "public"."ai_insights" VALUES (51, 9, 'Daily Risk Prediction Ensemble', 'daily_risk_prediction', '{"risk_level": "MEDIUM", "class_label": "A", "probability": 0.30414017661107184, "class_probabilities": {"A": 0.30414017661107184, "B": 0.18994220727076103, "C": 0.09539491243432806, "D": 0.2373444815811446, "F": 0.17317822210269465}}', 0.30, '2025-11-27 16:41:44.562007', '{"narrative_score": 0, "coord_eval_score": 0, "partner_eval_score": 0, "daily_progress_score": 0, "total_hours_completed": 120, "attendance_today_hours": 0, "attendance_days_present": 15}', NULL, NULL);

-- ----------------------------
-- Table structure for attendance
-- ----------------------------
DROP TABLE IF EXISTS "public"."attendance";
CREATE TABLE "public"."attendance" (
  "attendance_id" int4 NOT NULL DEFAULT nextval('attendance_attendance_id_seq'::regclass),
  "student_id" int4 NOT NULL,
  "date" date DEFAULT CURRENT_DATE,
  "time_in" time(6),
  "time_out" time(6),
  "total_hours" numeric(5,2),
  "morning_in" time(6),
  "morning_out" time(6),
  "afternoon_in" time(6),
  "afternoon_out" time(6),
  "overtime_in" time(6),
  "overtime_out" time(6),
  "attendance_image" text COLLATE "pg_catalog"."default",
  "signature" text COLLATE "pg_catalog"."default",
  "verified" bool DEFAULT false,
  "verified_by" int4,
  "verified_at" timestamp(6),
  "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP
)
;

-- ----------------------------
-- Records of attendance
-- ----------------------------
INSERT INTO "public"."attendance" VALUES (1, 6, '2025-10-25', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (2, 6, '2025-10-26', NULL, NULL, 7.75, '08:15:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (3, 6, '2025-10-27', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (4, 6, '2025-10-28', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (5, 6, '2025-10-29', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (6, 6, '2025-10-30', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (7, 6, '2025-10-31', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (8, 6, '2025-11-01', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (9, 6, '2025-11-02', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (10, 6, '2025-11-03', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (11, 6, '2025-11-04', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (12, 6, '2025-11-05', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (13, 6, '2025-11-06', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (14, 6, '2025-11-07', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (15, 6, '2025-11-08', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (16, 6, '2025-11-09', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (17, 6, '2025-11-10', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (18, 6, '2025-11-11', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (19, 6, '2025-11-12', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (20, 6, '2025-11-13', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.140748', '2025-11-24 03:45:48.140748');
INSERT INTO "public"."attendance" VALUES (21, 7, '2025-10-25', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (22, 7, '2025-10-26', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (23, 7, '2025-10-27', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (24, 7, '2025-10-28', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (25, 7, '2025-10-29', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (26, 7, '2025-10-30', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (27, 7, '2025-10-31', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (28, 7, '2025-11-01', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (29, 7, '2025-11-02', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (30, 7, '2025-11-03', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (31, 7, '2025-11-04', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (32, 7, '2025-11-05', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (33, 7, '2025-11-06', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (34, 7, '2025-11-07', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (35, 7, '2025-11-08', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (36, 7, '2025-11-09', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (37, 7, '2025-11-10', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (38, 7, '2025-11-11', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (39, 7, '2025-11-12', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (40, 7, '2025-11-13', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (41, 7, '2025-11-14', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (42, 7, '2025-11-15', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (43, 7, '2025-11-16', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (44, 7, '2025-11-17', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (45, 7, '2025-11-18', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (46, 7, '2025-11-19', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.197183', '2025-11-24 03:45:48.197183');
INSERT INTO "public"."attendance" VALUES (47, 8, '2025-10-25', NULL, NULL, 5.00, '09:30:00', '12:00:00', '13:30:00', '16:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.201785', '2025-11-24 03:45:48.201785');
INSERT INTO "public"."attendance" VALUES (48, 8, '2025-10-27', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.201785', '2025-11-24 03:45:48.201785');
INSERT INTO "public"."attendance" VALUES (49, 8, '2025-10-29', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.201785', '2025-11-24 03:45:48.201785');
INSERT INTO "public"."attendance" VALUES (51, 8, '2025-11-02', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.201785', '2025-11-24 03:45:48.201785');
INSERT INTO "public"."attendance" VALUES (52, 8, '2025-11-04', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.201785', '2025-11-24 03:45:48.201785');
INSERT INTO "public"."attendance" VALUES (53, 8, '2025-11-06', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.201785', '2025-11-24 03:45:48.201785');
INSERT INTO "public"."attendance" VALUES (54, 8, '2025-11-08', NULL, NULL, 6.25, '09:15:00', '12:00:00', '13:00:00', '16:30:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.201785', '2025-11-24 03:45:48.201785');
INSERT INTO "public"."attendance" VALUES (55, 8, '2025-11-10', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.201785', '2025-11-24 03:45:48.201785');
INSERT INTO "public"."attendance" VALUES (56, 8, '2025-11-12', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.201785', '2025-11-24 03:45:48.201785');
INSERT INTO "public"."attendance" VALUES (57, 9, '2025-10-25', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (58, 9, '2025-10-26', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (59, 9, '2025-10-27', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (60, 9, '2025-10-28', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (61, 9, '2025-10-29', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (62, 9, '2025-10-30', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (63, 9, '2025-10-31', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (64, 9, '2025-11-01', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (65, 9, '2025-11-02', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (66, 9, '2025-11-03', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (67, 9, '2025-11-04', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (68, 9, '2025-11-05', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (69, 9, '2025-11-06', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (70, 9, '2025-11-07', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (71, 9, '2025-11-08', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 2, NULL, '2025-11-24 03:45:48.206206', '2025-11-24 03:45:48.206206');
INSERT INTO "public"."attendance" VALUES (72, 10, '2025-10-25', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (73, 10, '2025-10-26', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (74, 10, '2025-10-27', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (75, 10, '2025-10-28', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (76, 10, '2025-10-29', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (77, 10, '2025-10-30', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (78, 10, '2025-10-31', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (79, 10, '2025-11-01', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (80, 10, '2025-11-02', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (81, 10, '2025-11-03', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (82, 10, '2025-11-04', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (83, 10, '2025-11-05', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (84, 10, '2025-11-06', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (85, 10, '2025-11-07', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (86, 10, '2025-11-08', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (87, 10, '2025-11-09', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (88, 10, '2025-11-10', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (89, 10, '2025-11-11', NULL, NULL, 8.00, '08:00:00', '12:00:00', '13:00:00', '17:00:00', NULL, NULL, NULL, NULL, 't', 3, NULL, '2025-11-24 03:45:48.214547', '2025-11-24 03:45:48.214547');
INSERT INTO "public"."attendance" VALUES (50, 8, '2025-10-31', NULL, NULL, 3.00, '09:00:00', '12:00:00', NULL, NULL, NULL, NULL, NULL, NULL, 't', 6, '2025-11-27 04:23:34.317804', '2025-11-24 03:45:48.201785', '2025-11-27 04:23:34.317804');

-- ----------------------------
-- Table structure for chatbot_logs
-- ----------------------------
DROP TABLE IF EXISTS "public"."chatbot_logs";
CREATE TABLE "public"."chatbot_logs" (
  "chat_id" int4 NOT NULL DEFAULT nextval('chatbot_logs_chat_id_seq'::regclass),
  "user_id" int4 NOT NULL,
  "query" text COLLATE "pg_catalog"."default" NOT NULL,
  "response" text COLLATE "pg_catalog"."default" NOT NULL,
  "model_used" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "timestamp" timestamp(6) DEFAULT CURRENT_TIMESTAMP
)
;

-- ----------------------------
-- Records of chatbot_logs
-- ----------------------------
INSERT INTO "public"."chatbot_logs" VALUES (1, 4, '12', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-24 04:38:53.676964');
INSERT INTO "public"."chatbot_logs" VALUES (2, 4, 'dtr', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-24 04:39:09.418547');
INSERT INTO "public"."chatbot_logs" VALUES (3, 4, '1', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-24 04:52:01.607891');
INSERT INTO "public"."chatbot_logs" VALUES (4, 4, 'hi', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-24 04:52:09.225224');
INSERT INTO "public"."chatbot_logs" VALUES (5, 4, 'hi', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-24 04:52:26.829352');
INSERT INTO "public"."chatbot_logs" VALUES (6, 4, 'hi about jrmsu', 'JRMSU was established to provide accessible higher education and promote regional development.
Over the years, the university expanded its programs and campuses. It is recognized for its
commitment to academic quality and holistic human development.', 'rag-ollama', '2025-11-24 06:29:52.937682');
INSERT INTO "public"."chatbot_logs" VALUES (7, 4, 'dtr', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-24 06:31:02.332004');
INSERT INTO "public"."chatbot_logs" VALUES (8, 4, 'ojt', 'The Junior Research and Management Skills (JRMSU) OJT program involves a structured process
that begins with identifying a Host Training Establishment. Coordination with the OJT
Coordinator is essential for securing an approved Memorandum of Agreement (MOA). The MOA must
be notarized, and accompanying documents such as parent consent and medical certificates are
submitted. Upon commencement of OJT, orientation and training take place, followed by the
implementation of the Daily Time Record to track attendance. The narrative report serves as a
comprehensive documentation of the OJT experience, incorporating the Daily Time Record and
appendices. The final grade is determined by a weighted system that includes Weekly Progress
Report (20%), Narrative Report (20%), Coordinator Evaluation (20%), and Supervisor Evaluation
(40%).', 'rag-ollama', '2025-11-24 06:31:44.638308');
INSERT INTO "public"."chatbot_logs" VALUES (9, 3, 'What are the OJT requirements?', 'I''m having trouble accessing the JRMSU OJT knowledge base right now. Please try again later or contact the system administrator. (Error: Failed to connect to Ollama. Please check that Ollama is downloaded, running and accessible. https://ollama.com/download)', 'rag-ollama', '2025-11-27 02:21:38.884247');
INSERT INTO "public"."chatbot_logs" VALUES (10, 3, 'jrmsu', 'JRMSU was established to provide accessible higher education and promote regional development.
Over the years, the university expanded its programs and campuses. It is recognized for its
commitment to academic quality and holistic human development.', 'rag-ollama', '2025-11-27 02:22:25.231082');
INSERT INTO "public"."chatbot_logs" VALUES (11, 3, 'What is the evaluation process?', 'I''m having trouble accessing the JRMSU OJT knowledge base right now. Please try again later or contact the system administrator. (Error: Failed to connect to Ollama. Please check that Ollama is downloaded, running and accessible. [https://ollama.com/download)](https://ollama.com/download))', 'rag-ollama', '2025-11-27 02:36:02.552486');
INSERT INTO "public"."chatbot_logs" VALUES (12, 3, 'dtr', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-27 02:36:34.3907');
INSERT INTO "public"."chatbot_logs" VALUES (13, 3, 'jrmsu', 'JRMSU was established to provide accessible higher education and promote regional development.
Over the years, the university expanded its programs and campuses. It is recognized for its
commitment to academic quality and holistic human development.', 'rag-ollama', '2025-11-27 02:37:13.444889');
INSERT INTO "public"."chatbot_logs" VALUES (14, 3, 'How do I submit attendance?', 'This document gives consent for student participation in academic activities including OJT. It
is issued by the Office of the Dean of Student Affairs and Services. It specifies the student’s
details and includes provisions for health protocols, safety reminders, and liability waiver.
It must be signed by parents or guardians and notarized.', 'rag-ollama', '2025-11-27 02:46:42.101401');
INSERT INTO "public"."chatbot_logs" VALUES (15, 3, 'What is the evaluation process?', 'I''m having trouble accessing the JRMSU OJT knowledge base right now. Please try again later or contact the system administrator. (Error: Failed to connect to Ollama. Please check that Ollama is downloaded, running and accessible. [https://ollama.com/download)](https://ollama.com/download))', 'rag-ollama', '2025-11-27 02:54:53.144227');
INSERT INTO "public"."chatbot_logs" VALUES (16, 3, 'jrmsu', 'JRMSU was established to provide accessible higher education and promote regional development.
Over the years, the university expanded its programs and campuses. It is recognized for its
commitment to academic quality and holistic human development.', 'rag-ollama', '2025-11-27 02:55:47.259299');
INSERT INTO "public"."chatbot_logs" VALUES (17, 3, 'What are the OJT requirements?', 'I''m having trouble accessing the JRMSU OJT knowledge base right now. Please try again later or contact the system administrator. (Error: Failed to connect to Ollama. Please check that Ollama is downloaded, running and accessible. [https://ollama.com/download)](https://ollama.com/download))', 'rag-ollama', '2025-11-27 03:03:03.215179');
INSERT INTO "public"."chatbot_logs" VALUES (18, 3, 'jrmsu', 'JRMSU was established to provide accessible higher education and promote regional development.
Over the years, the university expanded its programs and campuses. It is recognized for its
commitment to academic quality and holistic human development.', 'rag-ollama', '2025-11-27 03:03:16.046864');
INSERT INTO "public"."chatbot_logs" VALUES (19, 3, 'ojt', 'I''m having trouble accessing the JRMSU OJT knowledge base right now. Please try again later or contact the system administrator. (Error: Failed to connect to Ollama. Please check that Ollama is downloaded, running and accessible. [https://ollama.com/download)](https://ollama.com/download))', 'rag-ollama', '2025-11-27 03:03:33.139279');
INSERT INTO "public"."chatbot_logs" VALUES (20, 3, 'How do I submit attendance?', 'This document gives consent for student participation in academic activities including OJT. It
is issued by the Office of the Dean of Student Affairs and Services. It specifies the student’s
details and includes provisions for health protocols, safety reminders, and liability waiver.
It must be signed by parents or guardians and notarized.', 'rag-ollama', '2025-11-27 03:22:50.29784');
INSERT INTO "public"."chatbot_logs" VALUES (21, 3, 'dtr', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-27 03:23:11.530002');
INSERT INTO "public"."chatbot_logs" VALUES (22, 3, 'daily time record', 'The Daily Time Record is an official attendance log used during OJT. It records date and time
of arrival and departure for both morning and afternoon shifts, along with the total hours
worked. The record must be signed by the supervisor and validated by the OJT Coordinator before
being compiled into the narrative report appendices. The narrative report comprises three
chapters. The first chapter details the host training establishment profile, including its
overview, history, logo, meaning, core values, philosophy, vision, mission, goals, and
organizational chart. The second chapter outlines the training activities, which include
experiences, weekly progress reports, Daily Time Records, documentation with photos and
captions, evaluation sheets, and certificates of completion. The final chapter presents results
and findings, including student accomplishments, competencies gained, outputs, and impact on
their career.', 'rag-ollama', '2025-11-27 03:24:44.050719');
INSERT INTO "public"."chatbot_logs" VALUES (23, 3, 'how to apply', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-27 03:25:23.729507');
INSERT INTO "public"."chatbot_logs" VALUES (24, 3, 'how to appy in hte', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-27 03:25:51.758768');
INSERT INTO "public"."chatbot_logs" VALUES (25, 3, 'jrmsu history', 'JRMSU was established to provide accessible higher education and promote regional development.
Over the years, the university expanded its programs and campuses. It is recognized for its
commitment to academic quality and holistic human development.', 'rag-ollama', '2025-11-27 03:26:13.020172');
INSERT INTO "public"."chatbot_logs" VALUES (26, 3, 'hi', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-27 03:26:27.883092');
INSERT INTO "public"."chatbot_logs" VALUES (27, 3, 'what are moa', 'A Memorandum of Agreement (MOA) is a legally binding document that outlines the terms and
conditions between JRMSU and a Host Training Establishment (HTE). It serves as an official
agreement for students to participate in the OntheJob Training (OJT) program. The MOA details
the scope of work, responsibilities, duration, and expectations for both parties involved. The
MOA is crucial for ensuring a smooth and successful OJT experience for students. It establishes
clear guidelines and procedures for student participation, allowing for efficient coordination
between JRMSU and the HTE.', 'rag-ollama', '2025-11-27 03:27:53.305236');
INSERT INTO "public"."chatbot_logs" VALUES (28, 3, 'hte', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-27 03:28:16.505341');
INSERT INTO "public"."chatbot_logs" VALUES (29, 3, 'how to apply for ojt', 'The application process for OJT begins with identifying a Host Training Establishment that
aligns with the student''s field of study and career aspirations. Coordination with the OJT
Coordinator is essential to initiate the application process. Once an establishment has been
selected, the student must submit an application to the establishment, securing an approved
Memorandum of Agreement (MOA). Following the MOA approval, the student will need to prepare
notarized copies of the agreement and submit necessary supporting documents such as parent
consent forms and medical certificates. Upon completion of these steps, OJT can commence with
orientation and training sessions.', 'rag-ollama', '2025-11-27 03:29:22.752379');
INSERT INTO "public"."chatbot_logs" VALUES (30, 3, 'what is ojt', 'OntheJob Training (OJT) is a structured program designed to provide students with practical
experience and skills development within a designated Host Training Establishment. It
encompasses various stages, including identifying the establishment, securing an approved
Memorandum of Agreement (MOA), completing necessary documentation like parent consent and
medical certificates, and engaging in orientation, training, and supervised practicum
activities. The OJT program is evaluated through components such as weekly progress reports,
narrative reports, coordinator evaluations, and supervisor evaluations. These assessments
contribute to the final grade recorded in the Transcript of Records. The Daily Time Record
serves as an official attendance log, documenting hours worked during the training period. This
record is essential for compiling the narrative report and must be signed by the supervisor and
validated by the OJT Coordinator.', 'rag-ollama', '2025-11-27 03:30:53.515772');
INSERT INTO "public"."chatbot_logs" VALUES (31, 3, 'How do I submit attendance?', 'This document gives consent for student participation in academic activities including OJT. It
is issued by the Office of the Dean of Student Affairs and Services. It specifies the student’s
details and includes provisions for health protocols, safety reminders, and liability waiver.
It must be signed by parents or guardians and notarized.', 'rag-ollama', '2025-11-27 09:09:14.441029');
INSERT INTO "public"."chatbot_logs" VALUES (32, 3, 'hi', 'I''m sorry, I don''t have information about that based on JRMSU''s knowledge base.', 'rag-ollama', '2025-11-27 09:10:21.221344');
INSERT INTO "public"."chatbot_logs" VALUES (33, 3, 'ojt', 'The Junior Research and Management Skills (JRMSU) OJT program involves identifying a Host
Training Establishment for practical experience, coordinating with the designated OJT
Coordinator, and securing an approved Memorandum of Agreement (MOA). This process requires
notarized copies of the MOA, along with parent consent and medical certificates. Upon
commencement, orientation and training are provided, followed by the implementation of a Daily
Time Record to track attendance. The OJT program utilizes a grading system that incorporates
Weekly Progress Reports (20%), Narrative Reports (20%), Coordinator Evaluation (20%), and
Supervisor Evaluation (40%). The final grade is recorded in the Transcript of Records. The
Daily Time Record serves as an official attendance log, documenting dates, times, and total
hours worked. It is signed by the supervisor and validated by the OJT Coordinator before
inclusion in the narrative report appendices.', 'rag-ollama', '2025-11-27 09:12:09.586708');
INSERT INTO "public"."chatbot_logs" VALUES (34, 4, 'What are the OJT requirements?', 'The OJT requirements encompass various essential documents and procedures. These include
parental consent via the Parent’s Waiver and Consent Form, a recommendation letter from the
student''s institution, a Memorandum of Agreement (MOA) between the student and the host
establishment, and a Letter of Acceptance from the host establishment itself. Additionally,
medical certificates and laboratory results, a student copy from the Registrar, a resume and
application letter, an Evaluation Sheet, a Certificate of Completion, and an Excuse Slip when
applicable are required. The OJT process begins with identifying a suitable Host Training
Establishment, coordinating with the designated OJT Coordinator, applying to the establishment,
securing an approved MOA, and then submitting notarized copies of this document along with
other necessary requirements such as parental consent and medical certificates. Upon commencing
OJT, orientation and training are conducted, followed by daily time record maintenance and
submission of a narrative report. The culmination of the OJT experience involves attending the
practicum culminating event.', 'rag-ollama', '2025-11-27 13:42:09.796846');
INSERT INTO "public"."chatbot_logs" VALUES (35, 3, 'What is the evaluation process?', 'The OJT evaluation process is multifaceted and incorporates various components to assess
trainee performance. It begins with a rating of personal traits, intellectual and professional
deportment, communication skills, and general performance on a scale from outstanding to poor.
This is followed by the assessment of weekly progress reports at 20 percent, narrative reports
at 20 percent, coordinator evaluations at 20 percent, and supervisor evaluations at 40 percent.
The final grade is recorded in the Transcript of Records. This evaluation process utilizes a
comprehensive approach that considers both individual performance and the overall experience
during the OJT program. The trainee''s daily time record plays a crucial role in tracking their
progress and engagement throughout the practicum. Additionally, the narrative report provides
an opportunity to reflect on the practical application of learned skills and knowledge gained
during the OJT period.', 'rag-ollama', '2025-11-27 13:54:06.951334');
INSERT INTO "public"."chatbot_logs" VALUES (36, 3, 'give me the list of learning competencies', 'The JRMSU OJT program assesses trainee performance across various competencies, including
personal traits, intellectual and professional deportment, communication skills, and general
performance. These competencies are evaluated using a rating scale ranging from outstanding to
poor. The program''s comprehensive evaluation process includes the narrative report, which
encompasses three chapters: host training establishment profile, training activities, and
results and findings. The report details the trainee''s experiences, progress, documentation,
and impact on their career trajectory.', 'rag-ollama', '2025-11-27 13:55:29.040675');
INSERT INTO "public"."chatbot_logs" VALUES (37, 3, 'what is the mission of jrmsu?', 'Deliver services in research, instruction, production, and extension. Provide advanced
professional, technical, and technopreneurial training. Produce highly competent, innovative,
and selfrenewed individuals.', 'rag-ollama', '2025-11-27 13:57:45.77068');
INSERT INTO "public"."chatbot_logs" VALUES (38, 3, 'What are the OJT requirements?', 'Required OJT documents include the Parent’s Waiver and Consent Form, Recommendation Letter for
OJT Deployment, Memorandum of Agreement, Letter of Acceptance from the Host Establishment,
Medical Certificate and laboratory results, Student Copy from Registrar, Resume and Application
Letter, Evaluation Sheet, Certificate of Completion, and Excuse Slip when applicable.', 'rag-ollama', '2025-11-27 15:53:04.443402');
INSERT INTO "public"."chatbot_logs" VALUES (39, 4, 'What are the OJT requirements?', 'Required OJT documents include the Parent’s Waiver and Consent Form, Recommendation Letter for
OJT Deployment, Memorandum of Agreement, Letter of Acceptance from the Host Establishment,
Medical Certificate and laboratory results, Student Copy from Registrar, Resume and Application
Letter, Evaluation Sheet, Certificate of Completion, and Excuse Slip when applicable.', 'rag-ollama', '2025-11-27 16:44:12.939134');

-- ----------------------------
-- Table structure for evaluations
-- ----------------------------
DROP TABLE IF EXISTS "public"."evaluations";
CREATE TABLE "public"."evaluations" (
  "eval_id" int4 NOT NULL DEFAULT nextval('evaluations_eval_id_seq'::regclass),
  "student_id" int4 NOT NULL,
  "supervisor_id" int4 NOT NULL,
  "criteria" jsonb NOT NULL,
  "total_score" numeric(5,2),
  "feedback" text COLLATE "pg_catalog"."default",
  "date_evaluated" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "evaluation_period_start" date,
  "evaluation_period_end" date,
  "status" varchar(20) COLLATE "pg_catalog"."default" DEFAULT 'Draft'::character varying,
  "approved_by" int4,
  "approved_at" timestamp(6),
  "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP
)
;

-- ----------------------------
-- Records of evaluations
-- ----------------------------

-- ----------------------------
-- Table structure for ojt_records
-- ----------------------------
DROP TABLE IF EXISTS "public"."ojt_records";
CREATE TABLE "public"."ojt_records" (
  "record_id" int4 NOT NULL DEFAULT nextval('ojt_records_record_id_seq'::regclass),
  "student_id" int4 NOT NULL,
  "company_name" varchar(100) COLLATE "pg_catalog"."default",
  "coordinator_id" int4 NOT NULL,
  "supervisor_id" int4 NOT NULL,
  "start_date" date,
  "end_date" date,
  "status" varchar(20) COLLATE "pg_catalog"."default" DEFAULT 'Ongoing'::character varying,
  "required_hours" int4 DEFAULT 300,
  "company_address" text COLLATE "pg_catalog"."default",
  "company_contact" varchar(50) COLLATE "pg_catalog"."default",
  "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP
)
;

-- ----------------------------
-- Records of ojt_records
-- ----------------------------
INSERT INTO "public"."ojt_records" VALUES (1, 6, 'Tech Solutions Inc.', 2, 4, '2024-01-15', '2024-07-15', 'Ongoing', 300, '123 Tech Street, Makati, Manila', '02-1234-5678', '2025-11-24 03:45:48.108096', '2025-11-24 03:45:48.108096');
INSERT INTO "public"."ojt_records" VALUES (2, 7, 'Digital Innovations Corp.', 2, 5, '2024-01-20', '2024-07-20', 'Ongoing', 300, '456 Innovation Ave, Cebu City', '032-2345-6789', '2025-11-24 03:45:48.108096', '2025-11-24 03:45:48.108096');
INSERT INTO "public"."ojt_records" VALUES (3, 8, 'Software Development Co.', 3, 6, '2024-02-01', '2024-08-01', 'Ongoing', 300, '789 Software Blvd, Davao City', '082-3456-7890', '2025-11-24 03:45:48.108096', '2025-11-24 03:45:48.108096');
INSERT INTO "public"."ojt_records" VALUES (4, 9, 'Tech Solutions Inc.', 2, 4, '2024-01-15', '2024-07-15', 'Ongoing', 300, '123 Tech Street, Makati, Manila', '02-1234-5678', '2025-11-24 03:45:48.108096', '2025-11-24 03:45:48.108096');
INSERT INTO "public"."ojt_records" VALUES (5, 10, 'Digital Innovations Corp.', 3, 5, '2024-02-10', '2024-08-10', 'Ongoing', 300, '456 Innovation Ave, Cebu City', '032-2345-6789', '2025-11-24 03:45:48.108096', '2025-11-24 03:45:48.108096');

-- ----------------------------
-- Table structure for system_reports
-- ----------------------------
DROP TABLE IF EXISTS "public"."system_reports";
CREATE TABLE "public"."system_reports" (
  "report_id" int4 NOT NULL DEFAULT nextval('system_reports_report_id_seq'::regclass),
  "report_type" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "generated_by" int4 NOT NULL,
  "content" jsonb NOT NULL,
  "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "report_period_start" date,
  "report_period_end" date,
  "file_path" text COLLATE "pg_catalog"."default",
  "status" varchar(20) COLLATE "pg_catalog"."default" DEFAULT 'Generated'::character varying
)
;

-- ----------------------------
-- Records of system_reports
-- ----------------------------
INSERT INTO "public"."system_reports" VALUES (1, 'Overall Statistics', 4, '{"title": "Overall Statistics Report", "period": "Nov 1, 2025 - Nov 30, 2025", "generated_at": "2025-11-19T07:48:46.458"}', '2025-11-19 07:48:46.469321', '2025-11-01', '2025-11-30', NULL, 'Generated');

-- ----------------------------
-- Table structure for users
-- ----------------------------
DROP TABLE IF EXISTS "public"."users";
CREATE TABLE "public"."users" (
  "user_id" int4 NOT NULL DEFAULT nextval('users_user_id_seq'::regclass),
  "full_name" varchar(100) COLLATE "pg_catalog"."default" NOT NULL,
  "email" varchar(100) COLLATE "pg_catalog"."default" NOT NULL,
  "password_hash" text COLLATE "pg_catalog"."default" NOT NULL,
  "role" varchar(20) COLLATE "pg_catalog"."default",
  "status" varchar(20) COLLATE "pg_catalog"."default" DEFAULT 'Active'::character varying,
  "date_created" timestamp(6) DEFAULT CURRENT_TIMESTAMP,
  "student_id" varchar(50) COLLATE "pg_catalog"."default",
  "course" varchar(100) COLLATE "pg_catalog"."default",
  "age" int4,
  "gender" varchar(20) COLLATE "pg_catalog"."default",
  "contact_number" varchar(20) COLLATE "pg_catalog"."default",
  "address" text COLLATE "pg_catalog"."default",
  "profile_photo" text COLLATE "pg_catalog"."default",
  "required_hours" int4 DEFAULT 300
)
;

-- ----------------------------
-- Records of users
-- ----------------------------
INSERT INTO "public"."users" VALUES (2, 'mark bryan', 'mark@gmail.com', '$2a$10$lOPVQ7V9QidRny0Ul3Ub/O6GjbJDs9M5gAF2wtLcmn1Kgx9zqufuC', 'Coordinator', 'Active', '2025-11-12 07:39:13.233646', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 300);
INSERT INTO "public"."users" VALUES (3, 'daryl pogi', 'mmm@gmail.com', '$2a$10$A2xa.uQkoA9X8L2zwDR/Ju2zSoO5VyW9nKveEJC3oWZIdv1ZsDh1G', 'Student', 'Active', '2025-11-12 07:43:25.611885', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 300);
INSERT INTO "public"."users" VALUES (1, 'mm', 'mm@gmail.com', '12', 'Student', 'Active', '2025-11-10 07:41:08', '12', 'bsis', 12, '13', '09', 'aasas', NULL, 300);
INSERT INTO "public"."users" VALUES (4, 'markkk  jaran', 'aaa@gmail.com', '$2a$10$llZIef4BGrn4eLM5ZPNNr.MAwPylGJulQhEs4z9lyH1tdJ8/iOJrm', 'Coordinator', 'Active', '2025-11-13 08:36:25.001313', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 300);
INSERT INTO "public"."users" VALUES (6, 'loyloy', 'lolo@gmail.com', '$2a$10$M9OTvtizeNWAFnzB.ztmP.EPE0ChqMb7guQTYHKCIzx6VsbjNEMji', 'Supervisor', 'Active', '2025-11-18 16:02:58.645645', '123', NULL, NULL, 'Male', '0909', 'Office: it
Position: ito
Location: dapitan', NULL, NULL);
INSERT INTO "public"."users" VALUES (5, 'markakkkaak sakskd', 'mama@gmail.com', '$2a$10$ukL1B7m1S4n.pl3krKsNcOyXdX1Z9ATUi3wZw7rw4ehZHR2QMhlwe', 'Admin', 'Active', '2025-11-18 14:46:02.782898', '123', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "public"."users" VALUES (8, 'Dr. Maria Santos', 'coordinator1@jrmsu.edu.ph', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Coordinator', 'Active', '2025-11-24 03:45:48.098194', NULL, NULL, NULL, NULL, '09123456790', 'JRMSU CCS Department', NULL, 300);
INSERT INTO "public"."users" VALUES (9, 'Prof. Juan Dela Cruz', 'coordinator2@jrmsu.edu.ph', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Coordinator', 'Active', '2025-11-24 03:45:48.098194', NULL, NULL, NULL, NULL, '09123456791', 'JRMSU CCS Department', NULL, 300);
INSERT INTO "public"."users" VALUES (10, 'Engr. Robert Tan', 'supervisor1@company.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Supervisor', 'Active', '2025-11-24 03:45:48.100842', NULL, NULL, NULL, NULL, '09123456792', 'Tech Solutions Inc., Manila', NULL, 300);
INSERT INTO "public"."users" VALUES (11, 'Ms. Sarah Garcia', 'supervisor2@company.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Supervisor', 'Active', '2025-11-24 03:45:48.100842', NULL, NULL, NULL, NULL, '09123456793', 'Digital Innovations Corp., Cebu', NULL, 300);
INSERT INTO "public"."users" VALUES (12, 'Mr. James Wilson', 'supervisor3@company.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Supervisor', 'Active', '2025-11-24 03:45:48.100842', NULL, NULL, NULL, NULL, '09123456794', 'Software Development Co., Davao', NULL, 300);
INSERT INTO "public"."users" VALUES (13, 'John Michael Reyes', 'student1@jrmsu.edu.ph', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Student', 'Active', '2025-11-24 03:45:48.104326', '2021-001', 'BS Computer Science', 21, 'Male', '09123456795', 'Dapitan City, Zamboanga del Norte', NULL, 300);
INSERT INTO "public"."users" VALUES (14, 'Maria Clara Villanueva', 'student2@jrmsu.edu.ph', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Student', 'Active', '2025-11-24 03:45:48.104326', '2021-002', 'BS Information Technology', 20, 'Female', '09123456796', 'Dipolog City, Zamboanga del Norte', NULL, 300);
INSERT INTO "public"."users" VALUES (15, 'Carlos Antonio Cruz', 'student3@jrmsu.edu.ph', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Student', 'Active', '2025-11-24 03:45:48.104326', '2021-003', 'BS Computer Science', 22, 'Male', '09123456797', 'Rizal, Zamboanga del Norte', NULL, 300);
INSERT INTO "public"."users" VALUES (16, 'Ana Patricia Lopez', 'student4@jrmsu.edu.ph', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Student', 'Active', '2025-11-24 03:45:48.104326', '2021-004', 'BS Information Technology', 21, 'Female', '09123456798', 'Sibutad, Zamboanga del Norte', NULL, 300);
INSERT INTO "public"."users" VALUES (17, 'Mark Joseph Torres', 'student5@jrmsu.edu.ph', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Student', 'Active', '2025-11-24 03:45:48.104326', '2021-005', 'BS Computer Science', 20, 'Male', '09123456799', 'Dapitan City, Zamboanga del Norte', NULL, 300);
INSERT INTO "public"."users" VALUES (18, 'mar jarantillla', 'jaaan@gmail.com', '$2a$10$HH7EM4qiBJaBmkv39EyA5e/wf3J2M1EN1GbGDUDE92IpTOq8MqZvO', 'Student', 'Active', '2025-11-27 01:52:41.949518', '123456', 'IS', 18, 'Male', '09700', '123', 'iVBORw0KGgoAAAANSUhEUgAAAOoAAAA2CAYAAADJaAUaAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAADmASURBVHhezX0HmCXHVe65YeZOznmDdmbzapWFtApGchBIBsvCYLAB42d/fA9jjAEDzw8w7zlg/Eg2Jhk/gzEKxgHLRv74wMKSFVZoJa/irrV5Vxtmd2Z2ctyZueH9/6mu29V9u2fu3bU/3j/fme6urnDOqXOqTlX3vTdxb8dHCgkRyYEsEgVQCmmFpCTwJ4KEMJCcyCUkn8h7CaVISAr1FrSGMGybUfcUhYIUkknJC3mIaH9VsAzLJr3zUsTVSp6yuAsVqA4uBkkULkCGHGoJ849kRSJWeIKZyIHJ7Oorj6SEFvY1yF7wq6POk7hrei8O7OccmuAxDFt75ShIEjrLp9B/BZ//8kHeaTd5PVZannyzxDL50PKVw8jO9i8Oyr/tZIAWtJqeTVvQGXIn2bc2kWVY9t6Oj2pxlynNg9ppYDk4ozH2CCQgTk4zlgK1JlJ5iJvWeqLAYj6TIdBRU+hwHUYuBmzTOmopeDftHUtBdaVlCe4aI7mH6NIEnYmlE0nDRxG4THn2k4sVnsmhch7Y2Xkwns/iXAdJU0GwmoIOcKQAj84pQXtQZ0W2UpeOHmBXB9tOSZb9pw1iwIPAvt0WoNk0dAMBIlswjkrLsQNVdK5oMK+dOuImCYP4O0mUixpgywPLBMvmcMqBW7s7okpywnumbMhRCSQXHTWf92dG3udsloB2E/DYXLjDi2D3miaiwA5jZ8WrxGcynEcHieKMfjFAu9DOSp1FiTyfKQHLIVyADFFyGxgDLL3P9lguT/7DjkrYIjGMMTmHHi1wGHba1ys6FZLAGtow+tfB1KuL7KQxm5UYGm9whFB+md8rxysaEZJ9dpgn2Hb5MDPZMrizM1qJjsAfBPQuwkB/gc98wZ9RmTWR8+1TuYN9xoE5SfE50DzsPZaDS43k0ElmkALf5B1/6qy4XmlmNZKhLGfJYIcgSvFOCIZTJKapipDRnkeT6ZQ4Mm5q6rAUhq0/fE/T0T5Hl4siVTOHANttpUQ3ZIgTRWZURR4ozeolTDlMiRzgSLx2UfQLlS4EZg1mD0BlzyIDZswEetUQ+TKF2C/sdBLzptmEl8BzDk0m8DUy0uwKtA4au87CGIY0UjHXBaRzDuNcaGgF5sqA8g9iSzwH80FSz4sjaB56LSAPy2pd0EXBu6cE/shjHLHvTa5oIl+qLtRZajcez96xYsI/RvwcxFOICBn+55FIe6JmqZeoILFYHjxI1pu6ionglc4QV1ArBVGwePK71yX+8X4S/yxpW0gLw23LhVF8VO3lEVoFUbh4ivsz98EDlBxHrtNmswzlDHgvbrYtG2m0j1lFZeGRdWEp4Wudf3BCdF4eYnKC4ahr5Cb5MlKPeqSTapxLnpGksPdopMZQo/qifLA+xiOsyeM/TBg0ItM90tbT3hFU4Dl0YGVfnUwcZUoHyUXUfVISIlg9VEosR2J3kZKIHpJwWCXkyGOmTMFUonxOdVcA72m4Nfq6wHU+ow/WgXRJRcWeAJmOYqYcsgwr05bIII/4p4TzoqGATLBmiSVXnhFjiZ3KUUHLR2qkDEChsP5kDFlHtJROc8XroegFlocQf+UQOobzIZ2P6xs06YU/Rl82XwpycrK0+ajXKFCbql+EvJzRsqA4NtUnIP/Fg/3H4NvM1BURByUd0Z3+V6FIHoN67l6HyQq2ClhvmAi1U/7xWBlp08XlN+UwxAjGOG1a8mlvZtVMQaLdc8Fmgm+jEw7UHERxn/+iEcVMOWRBfauRgbgWqsJNHmlUKQqgnWHIdK5PxlmDgpRHgMvERWKlKuicruPymjOrDYVz3O1Ro7k4GdiJ1fA+rrMTUCL/Svihw+WhK7aLS9pZeOPGhblC3XDWNMgYige3+UsE2+GgYALvCgntc+KgtL4hW8Rdu7QyDG84ss8iiIaqs1gZdUWCRatY1g4ajn3T4TBbsS/zWTih9kHI/pnGsN+jPIj9C65QKadbnEYJzXYvdnQhmZHDh6bhH0eYAnuE7TttsnP8DqIAPP7/BzpmOLzNIvzVUFj/CCuD7bRKiLrytefqsAhWr7tKaMMOtqpg8kcKa98MGzZy+UHCY+OiKFLW7yNW4s3o5xLAfsAaM4d1P/cV/AWF9S+4nDqka+c+kTflD5eWGPXCuRlqYLpVZw0aCyvisigJY3DXmmWT1yhhGbDkInzP0vcLUXWHqVLQIbmZxKMFw186brBOf/ApnyxfcZz5YavO4hjskpzJ0XaOTgugSzGQoIYIZ42rNQhfrouFL0f55OPS218JUW2TLPxr8lEhJZKIWMzyIocZksRddu00ZgGi2wrCTUNwBY9Sp+S0zM42566z6k4hF0IlZPJacu8ZIzPl3RFLzQZV6oaCw3sckQvWVA4FgMJM4/hlx7M4sqZcUgdg0kudiQ1kvQehNo3PTk30hLkQDkI5w21VQj5f+M8BwBsEuAiye1ccnbMYvXPoN86shaQZVHWixbHorDrFsoCpy0KTIoi7xq68YfJ7KI4uBShPw8bRthXmz96LJtz1WAiWYSnSyvzpPIi+TUKv3GunjkvJs/lI4v2E7gfqDjcdVsNYzrSQi2kAebI+YclC+9oSa7u/7cMafKpakJN+ZsDbMBf2uJ8YAA2AhqAtQjNmhjH3mJbX7WneJAt+HbY6Mxux5WhwKa1MetfMSQOOg+laAg3oZgSOup3vneIQ1xrvMatbh32OVxlMaW4FsaS5ikZBeYwC2uaUqD1DWcAH9KwGBh3noTdTL/5ztKYhkFUwb0oYuRNVcDc4dJKjuneHfUG15+HUuv5hOQfsrzTa5mM85o4Ca/L1FAXTTnwN8WCd6gKQmc+gLdecK1xQddHto2w+ibU7NwPhcBRQbdDwTCfkQMeXLlRPEbD1Mn90Dxlb5z5LtB5YiuTbbhQ4sOdD+pcsvA4ezi0la/vsp8QX2z/MiU13DYMPY3mCxtRRTUoJqAAG0TxFJUUnVaARaDOvyl6p02Ir193H4gaad7TvAIRL6T1zinOKyOe46HI+u2AaDvGKxz3WSXFx7tcdx/PqoKqzqCzMp4VyyOk3EhizobsEnxPoJfVMqzChdrRxoDPhfDpYW1norOamA96EZsgbw2RdBHm3FLzAfRw4cxCldZj6o/kgKBcpUHFZYH3aT5A57qW31ZDAAJdF4QRk48Bj9xKKdeMszkkJ3uEefrR81D+cFH5BJ6OeTKoFE1aX3/JSOgfCUVNV4NcbmZCR3cTaFPTH4t5OuYDRcPeKlGS8pc37FZCH1Snuz9wvVgnSUBI8ltgWwGv6sDskuHnctDCF4ac5jVdEBqb+6D//fim50M40U2DRSYlwPqZwr4Hv2XKIUjbY2R7pjiPKK3GjAzUptxihErA2Xd0o4T5G3SQUzfZ008Mj9rcSSvLa35Ry6fuD0nrLJQCGos8gca06YxSiI5OZMkysszLc/nDJQq/pQKjWtTkfpSmRCLFv2ikty4lUG1IBkLFiZwWMMuC0dH1jWpr+/YDG6C7xD+GBFclFWDzlwnt6bYLFKMMyaVbZND5rgOH6KgPqgXaTiI/cxzguxQFiFkNScsjX3QogHgnbXyX8MQHVqpHq0yGU9ogOmONuJKd5OCHfZU6QDy5PWBuHdk8l3ARhGbbBFsmpbU/bZD7aiWOkYfqvBG2E8hne6KyYQ0F0WNPX0XYQJIN4WdiGITq+/qmNmjLOGBnpT8xjdReG2qrHhi2q1uJmZr8GnpqUiQqylgWtD4aeChk6w0XdpeaRa7eQqEYB7Ax2CsWjqVGN3gN1VSvTgsQcNFZuH/DPPMu9FGdljXFdUS5MJ/A/5z+jY8PTirXiJsM9PmA3eU1uDqh2UDWLCtzTW8Ha9DVEJNlUHqmlgMMaZvTIdJcuVeoiULe2VQlpGdP/3AgyE4ftZ9xBH1tbiLIDQ2ayoRxhWUyvIpSm/YHyIMYwaUQyVbBL7i0YB4YuqBtQ3OTHesP1o3vQP1ldl3Lew9iigzbrU9hCpKKzKr8RLYSgIwmMgk5V2vSlwdREHgxpJyCRwVvcSxHMY9IpgN8BbseUdBLiPoaEfMyRAplNh/8amM6iU3m8obfR/6bXlTMjodGOT5TJvG5Igm7QkboDjX7RWVZHfOYljK5s96pjevdNHpNPm3WIHPGovYyyaiMem5Y4i3DQs7VUQixq6+Yyp/ior1xCGS6NjH1wp4Dv99BOcBM8qRPk+SFGOpyxgzAZ3Rh+LIJ8miHYknVMqoJHliZZnamT4maUs1q49ZsIABIwylGeKIcDJluos4LctDB4rzjb5ckuU9wSLmc8r5SM+GZTwycq03fS4L0g8X6wTnV0j3geuE+rBYVltlJVQpcG46Q5rh+9zrKEcVb4yRq956SrTjCq8+Vt7naiU9CB0AGsgzUkEX24YTj1k88vaz1sjy+QF/tSyew6urBXliPWojYSIqoyiYEm0pFWIT63Z4RfHAguhsgXCNWAx4JUIQyuQgr5tX1MuLbgk9e25vDrcolpYUJRNTkzuZkEa188cm9Au4O3vHR7L9g+OSbnlliCj05xcMFryxCzxTFGSmHk1VfcaAA6Yrv3DeccHfxGKyM6KBmnAFZoJToTDKGQwMiInokm8ODNDmHiiwE8kkv+jwSa4V1yXykZ3Rn5yffFkacH+0kKhxJI0wfooXQzoJnyxmpwVE9CPd4sSx+lExouUZdtR8uQKLeR3T/av1JZWbJ4DZ3SoHTH2H3AXwEpyzhlvZbLSol8ZjFz8pz1kHNaEy2pwIHJUx3zmfsuUX9BuPfjwHtUtaqbn/Zh30PfeercI8ZphhMywJYNmTRDfjo1ispA7KPE/e3mOWoYpimKyozRUMbV4A24/rHgGe8s891GGFZhmiOFqSvZwXrBzqinsQxGnEZNCmIWPFwwdZpWwFULRvu0qV97Nbck+clS5ZochgoNSUnXmXpEFiQ/UqX5bZkc6nTfqecdPlriloufy8MYwyZbF+quBz813mXoXp735tgBFkhrxVrGaauwiDLTLv84b0S5DMwLixMOKop55Jt12m2AzjyZEku4Bx0Y4B76IdmxKPnzRs4gmM/hEf/zHeZxhJGVsynORoxjWphzkxZM9+rrZB2Q9byRhfXqvVrMEo22PYPCiNGTW48FLYT38h3oE2MmIovL6GPajwXOuxOG52X0/zhnf4ukZLuTUr0Ex5gw7ZpBEzWjDHsUFUphmNwa0IUXu/JSMw/+Vcckk9OHVxf4SqUjfCILPkZdHpEDfZQCMa9n6UqUzz7ZDoNrUm7wmfZNbTQBdVTLRLig6UY7LlUG1rUMys9dgFENyPY/e4Nsu7NXGtpqIKhmkdzUBVk4clSO/vG35fmvTkkaSihicllq3vgaufY3rpGeHSgzNyvj/75XnvvYCzK2gBgedSSW0eHdG+WqT7xWBnY1S7XjAAIHWEL988dflWOfekIOPLYk0n5BUmPdctkn3yhX39MtdakLMrv7RfnuB5+WM7Ous1JBnMet/Ab50WVpf++PyY3vG5CWZpGlI8dk3//+thzYi9Bkbkmaf/nH5ZZf3WjunTgpr3zoKZn9yTvl2h9DW+kFtPWyPIu2TmtbaAM85tdvkWs/8hrZtKtFMtDYzN5X5KWPPSFHD6Gr4Iga+S4sS/rmG+TGD1wl67fXSO7soBz8BHT28Lyka2CQ3QNy3R/eJpuvb5bU1JCc+OtH5Mm/XZaNf36XXH832q43/JdgakpGvvaUfOd3jstUZ0KqITeNIjmalo5fe73c/J5+aW1zlVqK7PiYnP37J+SRPx3EANMmWz/6Wrnmzb3a5uLhU3LoLx+Xp786LVVwZIJO2vm+N8qtv9IvbaG6s+ivxekpOf+tfbL3Y4dkOJOSmgSctH+73Pzxm2Xr1XUic1MyfP9u+fZHTsly2zJsa6Nc96evkR27mqQmOydDDz0tj//6EZnavl6u/50bZOutrZJZnJYzn3tSHv7kEJz1gshwF3TzWrnx7h7ofE7OPwgd/NYxuXDXtXL7/75a1vVnvIHLIDu9KPOD4zLy6EF5/qOH5Hw1+q/NuwkksujHpQ7Z/pEfluvf3CP19QlZPHJaDvzVbtn94IxUt/mOzTMsONRZzXUQHKbMBOE7KpF6a91tH+Y4QOLYb8a5MJmZtWLKwlWbBmTn/71Hrv2ZNVJbn9bR2iJZk5bqvi7puaVHqk6flMG9cCQaJ8u1bJQr/uRHZPvtLVJdXy1VrQ3SdGWX1I6fkhOPzEqC+TAC1r7uBrnq/TukrRN5mM9Sc43UdDVI49a1sv4ntkpr4rycfXhGclduliv+5w2ybnMN8tRJPUbfmWdfkaEjkLPacG7+Wye1OpjGrNYn/R96jWy/tUWqGlH/2jrJH3pVjj82JanX3iK3/NEu1Ftn7rWnZeHlOWl+27WBtqbR1jm0laxeksJEkwx8/G654ed6pb4RPKNc/dZeaa+dlDNfHpE5zEbJAgxrskO2fuwOufaeTqmhXGs7pbl1Xs5//YzMLhSk/jXXyLW/tkM6uqol09UkmZlROfVKg+z4vetlPdt29eJSe6PU1c7L8OPHZXoKbaFv0hzSG7tly2/eJDtuao4u51Cmo1nqZEyGHjwl6Xe+Xm7/0HZp7zD3atd3SudAQcYfOyFjiKiSqXk4Wq9s+r1b5MpbSuvOtENHfa3S+ZpNsu7yvIz9xxmBKNL8puvkpl/CANiGPG2N0lA1Iae+cVpmoJrMTZfLDR+4XLp7UEdrvTS1LMvIE0ckffcb5Nb3YzBor1Ee2zZWyfwzh+TcYQzyV8O5P3idbIBuMihTX78kg986KTX33CQ3vr1PGsELbc5STVutNG5ok57XbpEd78RkMzkkx568IFWI1FAbZu6ctP3ibfKG390mHZC9ur4KsndId7/I+COvyvkZ6LY43tO2aE/GujjbG5vzwToNGXdVcuPj0i1rVsFsnLgrp8KUSNs7bpGtd3Y481IE+jbIxvdfJ2v6CowgRBDuJneuk7YdDea+RaZBmq/rk1acLvCaLGLoW7FuorlDBt53k2y7Iy3LE+lgmIuLVAYJqjsTdhmycnu6yMGL2/jKJPNZoK4arnyaZeAdO6Wv36+YM+qrexb98I1AW2nb1hLq39In3dcgEjB3PaSl8Zo10rEdHGC8SuYxs9PYms1zQYvGHxqQDbdlEDrjAjOP37KRJ38gG2x7BdBU+BYUN5EQ8Vs7qgAw1vlG6b6pT5oyXpKHTP8a6bsyg/AcF7kqESx7gsuMKKSl7U3Xy673X6ZXBQrilklXSZpRArumhltFDnCRO5GHc6aFqrZIbVgn/Xf0SRV4VUW693CdnF6WKkwcgboikOnvl6t++4fk6htzsnSBDMwidGyRnhuiZO+VvqsgO0NLD1w80GICW0fO8pHgVZjQLXRGQzRQf+PGhZ+nXCrkOCuukZ4f7pEGR4DcqTMy+JX9cmrPqGBpVUTt9g3Se1ONJDFKchJp3NklzQghg0hLw5Zuad5WwBrES6IULkZG5fwzZ2T8xAV1syL6emTd69ZL8nQg1YNRh3l26pNxVleuUiQwA6Xu3CEbf7THd7jsrIx88Xk5sncFT+E7uGs7pKXXLnB9pPqQvqXGGHcc2nqk765+qY/hK7jCBBAWTjw3KMPPWDorg48flkP3HZJTh+CkCMV1sy0FZ5o9K8fue1kOPnJS8w0/NyzzHBAsFudk9Dmks45HDsj++w/IkLRL2+YG6C2EpmZp3dIhhflwR3kAX2f+6QXZd/9hObN/zu8zeGLPHQPSPwCbcQzdolhbVLWzEes/1Nd7x2U6GeQX6GAuIPcYWw5Wlj09IueeG5Hx04veU2eD9KZ1MnBHjyQmUW4Z+lrXLO1b6kudHLK3b2mXwkywXvYNV9UawWJkrMZAZDc4Qz5bBC0xAOajsmPylw8+VO9tk4Y1zqx4YVSO/+HX5T9+5ivy6Fv+XY4i1C2iGaHtRsyVS2y5UVq2dUhtaIQiaMTNGxFCo/OiTHTp8CF5btffyTcGPiv/ed+Q3/FSI3XrWxCmxUvmz6bRxh+FQjYpG95yhXT1eQlA7uBROfLQOUlsKFFvEYU59OP2Hmls9xJcoIM7tzZLAWFtPDLSceuArNmRl2U4UTAnr2BALqYn5fjH/0n+edc/yoMePXT7g/Lkp89KAutH84IEIgZaSlOVzH5jtzz6hi/K13Z9Qf75V1+S4TGvHmJsWA5/4AHUda/8yxseku/eNynVr++VznURHZbOSNv2Fo2C6B4lms1dkOnH9sij7/hn+do7HpdjR3yXyKzrkk6Ej/rCW0WI7r+6K/pl3a6MLI8Fe9icQ+5AsazM7X1R/u36L8jn139BvvOlcd9Z4fRtl7dLC07zsMP0tu4Y2aulbRsGKpwi6A+APWT9jE6qj8dA5nuWmBpEvCVdKjQsySBeN5eKuQuyODqna9PUuSmZG3YclSFoAxyQ48yaTmna1lI6OhNt6PStsKyiEZcGK4lmxgWTMrFvUhZ87UqK67v26E68WHAzIzybnvvK83LsewmsAePaIu+N0rqzQ+oi+lfSDdKyE+tQnK5ko6nNa+WyG5tleTw8Q0QjkcbKpw666SIh3O0qSFUnTAAOStsg5YvOCn11gZow21ZHyFGFAa0Rzt3FdRqcYHtH9KADvddt75a2rZx9YiIMfZEDdY1OyfS4IzFi1xrnScIlo61d+t+4QZqGy9QX/rioSMu0DO8f596fB4TVXVjbdkJPWH/WbWuXZmdzyUda6rd3SQdkr3Kiowg/LOo/eIuyG+JHUO1jNp9wjwUM8c+9Lo+ECuagHuibZVnmt+tphiwiqGzAEFNYe/BmobdV2tb4IWFufNYJibBOhRPXMx/+KEYQhgPOi3nU74K7zakxCBiDIu8OotJcZG7fKb3rvQtgaf9BOfTlQSzH4tvRObu1VVoRKhYdHOHkQjG8hHH3d0jTGgxa1FccMu3Sfc9WqZ0ob8phTewWOpbdsOAXqDMMS/LNLD3PI40G6skdJzzSC3xgqvF5jbTDWP1BJyvz494pkOlFWLw2LQnIojyY5CJ4TZ7QvO7mFwGxlkue9JeDuDIZabsFUUh9lL7ARUwxvqm6yB1pp1g6k/G+fw2RDWSvd2Sfc2Xva5O29agApsjq6Yxco/PI4vrcFfXqOyogowtYCBJd0m8hDBOfVdPOqLiot0fKIVU6/1CfD3vB47iMP/WqjJ8yzrR04IwMYT1AXdRv6ZMGZ3ReemVIZhEqGqSldnO7NDbnsUin6EFnNFCVwH6Csy0/m5lvpxqC4LU1YGugJJ5b0jweFYFBo+tWZ6NscVRO3/eCHDuM2ZQdx0rCYBqigcKGTmlZ70+nubOjMjHsy1J9GUIr7qVwCVHkqBSN11wm6zCzBfgCwtdEYRk6m0PHj5AwCIxgMMNSo8BPofPFCj7v5hEOyA8BrAZtg+tHRjn99XADD1NTcv5IscOwrGnW9WtJ/GfB9tDzCYSQHb2+TmRuTuYnMIDgNEqeeHCLJhqp/j4Z+Pla78qCtVuKABmgYbqgaeXAc1urtG+oc2SflvNHHdmbmqR9Y70kF73XDtEEv05LfQ3X2ir+6fshlpiGDHTOIlkTcIk5iy+1aC0mrSKKgVV6qh0Bxd98U/79sj+QBzo+Jl/e8WXZ9805MF8lDVtbpLYYMl+Q2QNDMuWskaoRGjcPGF4jm5qikWWkaR1mrKKvYvaempUld61FqMAAFMS3VrjA5xs2nCxYS1EnZWBh9345+MCQSIvhKoo3pnFGzQy0SCNCS4ulk4PFQUsB42/b3AzHWoWD3rWy8c2h9agitBPV1CIDH3q7/MSed8o9oDc99tPy+r+8Svrq8+bTMtrPhlIcZaM1WwqwXFjbIa3rnTXO+JiMHZiTYoBQ3yBNm1th2xF1pmqk6fZd8tr7fkp+8u9ukcuctf70i6fl3H6E4lHiXSwyTdL3Y13qZy7IWZkS+5iGjfQgWgjIPi4jr7iy10vzFsiOBPq69iQasr1KosPaGZU+R+1bP7HE6x8cIuzLJunbIu1VkoDDMlBNtGNWaORDl0Zp3NTiO9giHHXPMZkd8dezqa4WadnSEFW9pLo7ZMNn7pIbPn+3XPGza5214wWZO3wegzrFdqCXduTCequAGRdHfhKCDhvVRiTOvirf+/SzMjjmvcywCpq2djiDEULFE6MyecIJ8WHcjZsb1aBCHOtMs2AH7XS9dN5Sup5nmWJdBPK1XLdGum801HfbRtn0rhtl210YDCbLltIHHDoJy0rkk5JZ1yyNfb7pL46MyeDzE86aLoM+bddNFY2yTKIB+Frz9mvkip/fIj39ToRx9Ii89Jf7ZRjRh76FWhHC0cCizI9YZtLSfHWnYKnugPJbqgAYzavXNUlTWPYXpuSCI3vTpjbdeDK2V0pmoeaTfqWzThw+/WAdtQRGGWQn/CiElMxizF0DJxxwtvlnJ2X8lUmZO+VsPNW3SAN3iFGPfgO8g9TmbbL1Pbtkx7t2SmeXlwjkTp+R00+cx/qXyikF1wwK3vaUo+dAOd2XG5+UmZPgMfC0JbpkQtqkFYNRne3f7KLMvDIs5w9POY+sYNxbOrAWj6glOyujB/3wqnZbj2RCT3nIeth5S5DhBh6mq3IEjAB1VpgVadjWKU3uoHNqSiZfGpUFzDgW9esh8w7kHy2vsVRTA6KmBo1wYhFrvaE+Rmg/zc0g7zLV2y1Nzb5zGVSoBAxUjL8adiC6c2Sfg+xjL2JCCMiO8HhnXjJLHEBoWCsTJzHOrC79YB015EQu+IyycCEv+bG85MawQgHlpyD8ADq9z91ImpDpPcMydQphq5cm6Rpp2NSKuRf5y9BvDrPdoU98R175Tlaqe8sQmf0M4sZacc3Ndpgeg9TObbLtXVulbjYfDjqD4Nqvtk4a+p3BaG5Wpr5zRCaeGXeeV6b1cVLTGvAB3QSAxfbkI2f9HW1YStSjLHa7j6wsjWPNN+LT7PMnZXjfJCwpTrAVBFaQL4SuCNEzxfZzMn98SkafGJXpqeKoI6m+ZvRr9NoxN74oi6AAv129cvmv3yCXX53gOFYCrtm4nluVRQ/zzx2XCbvJk8YsF7lLWyky0ra1KSD73PFpGXliHMt0X/Z0b5M0czNNnwfT/lajHPTEgcBomMTUFUAtQBvBbeDyKBZehgtLkrjiSrn6gZ+XO77zc3LbZ2+WNVvyUo/1p7uRJNla6fubu2Ud1i7cDDJIS20/ZiSuXThIuUCovOSs5bnGHX/wGXn5c6OYPcKZDVbsa7t246n+j0ON9P7sjXLFWxskOcrrKCUgbWFR8ls7pWWN41lYGzf8ylvkhrc30p+KqO5rl5YN0XPK/FcPyPA57yIS1cEZdXxY9r/rM3Jv96flPo8euPFfZd+evKTqvDwedPDjMK7KjdaZysJBpw089jtvV2H2Sg9skdd9Zr1UO7LohhJmyBJZFsfk8Ac/L59r/5T84xu/JQf3+16pGz+7mkx0c4lITA3J6X0Bw7g06LKoQ9r64ahekpF9s9z52XWScXmm7Bug5DJn1ChLi9xMsqTQXSU0wJyVUiwg5FyjrH33LbLtZzdL9+2bZd27b5bN96yX+svdjSQ0vR2h7C/vkq0/vVZqnWhFN5R25CR3IdjO0nf3yqMfeEVmi/1dI223bpSerbArhGkrgaOYUZIlOglHNyoPOuAOUwAXZOaEE5J3bZAt771G1nYjSliONvD8xAJ4bw9sJPEto43v2iU737VN2t23sbibOtBKbXkJPlLnjsnZFzAbVoBENcbl2pQkO9MepfTd6qDMHql3UAa2HW7fpCUWoZt14NHZveaas/ut18hV77lGLtvsyJjBmntHG2ouHXj0+W4yJYv/9oqc3DOl2lZkEClsa0dEE92+8lBSG7kv1X2iMCdnnhmJ3XhOZCh3GH47UchjgGoLyd771qvk2v9+lfRvcmWvl+btLbqhpHszK1I0knxYEUV8C5Gfn9POYgxoz8slLbMSaqXaXSek01LV2SFNMMxyNvm4odTYVSNLU+HcCKEfOyznnR3U1PYNctmPcpqmIqKUbtfNMCLvYbL5DAN0geykSDViBJ3410My5gzUtTftxODTg5kiZoW4nMXasy0wGMWCG0oIraJqSvZOyOlvDcpMRFi4Muj2ZvCJI0rqD1ox4IyCSCDFjaRVPmFjgDX3ujZpRs3xyCEaMr+capCSmvpMpD0YDkHh6njdXMp3IpmTwUfOyEhcFBKjR20DA0VVyn2fGlhelkJbE0Lo8mRvguxmQ2k1ROscjkqDLCV+Ys68pI+CGvpVSCwDYXLOhMOXqTN8U5rPP1vSUl1f4xshjD63lJKm9RHvi0YBRtyyE7NNLrwihHMdPilDmG38kblDOl/XD0VFzE2awH+4Ryflr2hhUcrvZNLvldUPxuNcvx4jtGMJJM/uk+OPOTMb2rrs3TfI5usLsjxc0poUZhuldXuzv5G0ImDcA9GvPSY7a2Ty2Vdl5KwbX/qgpGFevZ6BfvlaeDxxiOYjmtJWHaguEtK8oZNvPJaFzECztAwYHoIw+odUfFrjABFTDr24ADtyxcSiMMlwHc6V4ociXIPhrFUf8VyZH195+KQMxoS/VjdhaHouLZm2msCHHHLzOam9rjviffRo1ED25q0FqcE6lV9SZ3+jKEz8pQOfD8uVThjFsSlAvEnV8av5dYvYmyTLJSIxy/Wio2E4VwMMjw/T873o4AGnV+DRizM1Uue8kSQjR+SFO/9QvtjxUdBfyH/eO+o7X7pBX8+q1U8wuOA21YgMPznshL8iDdf0S9/r0rI8FGF+CL1QHRimQiD7eShsJIc+Z3RB86E2opHAGHn8Hw7IeedtlNTOTbL1bZskORjmDUZU0667mf4ANSnHPvBZ+Xznx5X+5X8clJmiytJSt65DWsBbSfuYaZJ7TyH8dR7prIICt5QXMCCeh+EXKSvLORNBFGdUOmmOO49wRT6C8cq7YFoSy4rmbe5GUlZGv/B1ub/7j+Sz3X8sn7v7SRkc8W4BmS7MvhGvGXJmLsBAc/1rZc3lqM9L5+C9eGJGZmeXZNHpS9bTvo4bUylp7u/go8oispNzsrRUOgryfYCCDMngUwh/I8e26GEJliD52m657JYuZ3DNytzZeam/qiUg+/kvPCR/3/Nn8hc9n5S/evNTcjoke/N6VIC2tRrwE0fGB9knPq2ymWQC2fBWcTmUrM5K4sigjGFm83drW2Tdb/2E/PjTvyR3fe1O2bDdV2hu8DzC1Yw0OLtxuZFJmTm1iJkWzI5NysLZCX0RxiAttevR8TVRCk7I9FNwHvcFgr4e6b2yVfJTC05oBbSvlSu+9NvyjvO/L79AGvl9+W8Xfkvu+uQmaR4taERkW4BYJSggZF/42vNy+NvOICIN0vXGnbLlZujAS7HId7RKo7OrLdOzMntqWtfPCXjo/CnI6Qz6qTXNUt/rS+2Dc+aIjD4zHGF4HKyWgnK2dcvl//Ar8gvDvyHvsHTqPfKmf7hauhA/6ksPyq3HMSxD31LiV7NGba0jKSGQhS+VeEncnl04MSvzIzC1pWXJQpaZcYcLTD/tawNTJiy4Qda+983y1r3vlp/b/Ra56lbH68bHZPSVcSkcG5TRE46n9g3I9Z/5BfnpPe+U1//6gONAizLxvWEZ1828MGj+OTn/3JnAoGoQZUNpafqR2+Rtw++T9555m+z6EYevxSmZeHRWMuuct7Eg+9yrkJ1R1OKyLJ/ie8uO7HxDaU091vVwO6jYPk2IJAyUjGZdWtFRyT5HfpTV88ooI4mqGTn3ze/JhDOySHuHtO5aKx3b3RCXn6A4INM93dLg6GN5aALOidEFns/Pxc/CCNyRtXp9J9apbC0IvpQvL5ySoe864S8GidbbB6RzrhBca0QBxtN0JerGoJHkaO8lE2HHYzicklE5+cA+GXHkTG3eJNve3l2i4PSmNmnsdjiYmpKZ01gfMAmLMXXUKXOLSLUhXNwC4w6ICaOD81Ark3tPyNhZL7kIDhDeV5UUgaVGW73UdjmE2br39ZukZxsqd8YCbYqK4wgfgwSf6G9ulMb1juMtXpCZszNqiFw8Jk7DUYedDkNE1XxzW0gnCO+v7pNuhJGtzosDlGHiqSNydPeyJI6+KicfHgwMSJnN3dJzI8q4j1lGhuXkvx2PWQcaBeZeOiPnDpSGv8k1TlxrgaiFL99nQuvQ+T1H5bkns1imBWWfPjsrWXouN1/Rj9MB2euleXODpNHVVA+5iSXonr3rEkJf3vrBINGYl+Vv7pUD9x8JhKFBZGX628/L/k+9JLnAR0lmZerFc7RjM1rAgWf2nZIJd5YEqjqzsuTUnZtbECx1Idq4nP/WCVPeAz89U3dDIhiOxyCHPMsYeTnRmFEOZcYRyk85HyTAwmlpip9VTMnyQ/vk6Lecj9Uhlm7Y0SQF/+M7GI8uSKG53hmgINMr52TyCEZZ/nBsFRzswFkZORDcza1qKATbRT2Lk6i3LiH5R0/Iub3ubH5BFvjMeTNspxw54XCBfYQwuFuDJQz1YZHDaLnEmRaLtrSzcMudHZbzL0/p9znp95tiaht9cSzwXDmFMDsgSySyMrN7n7z0qRdleAlr5pZlOfP55+XA405nhpGdk7MPPCP7/2UZAwFmND6btSwX+wnD15kzcvrJYPi7ODwrc1imLI0jxF5JZZB7/OFn5PHf3C3DdXX60UCL3LkRGYHsUgPZ+Z1KkH3kpTGNyCxS+ol5eByWV0moJ5KoOkxMYa9M/VTtD3+Yo28YTGFmrtLMsVKgRAFlG6Zl5hsH5DSEyGE9yW+H43fMLJ2dlIlnj8jxP/+mPPX+5zHr5mRhfF7SGPVlbEyGv/S4vPDBwzLLLx6DAPyXOHxSho8uSQKGkB8akTP37ZFDf71PxsYR6tVkZfbJ5+TlD++Ws2MpOCXaePqcTCcyUlVYktkXDsrBP35KXv1PhD4H+ZUvScnNLMjCmWmZH3To1XEZe+S78vIfPC3DCympZuMQJZHAdJeeldHnxmS5BgPK5Kic+8JuefFPT8tCB7+wbFbGnpuVfEstZpt5mT10Ws7c+4g8+6UJtJWSpVdPydFPPiYvfXZIsj0YpXPzMv7IXnnxo1jLgN8qxo/JNEKjURl6FpFAbZUk52Zl5F+fk/2fOyan4YzLNbg/dFaOfPJxefkhzArNMOLktIwdXcTMWyuF4SE596Wn5NnfPihz40MydGhJUvUpyc1CzsEZGKNLEzL1/DHZ/0ePyr7HslIV3imFMekgTr0fPytDJ5ckXZ+QC4dele99YrfsexR1j07JYl291GSWZOb5w7L//zwu+1FXdTNtB0Zci1D060MyXVstVblFmXr6oOz7zF4sE6DD2oyk5hEqnwvyNP7yKTn214/Kt3/pRTk3mZDqOkR0cIjk1IicvveoDE1jzbiQN+9iLyzK/NEROffoAfTXo/LEn5+V+U7YS01epncPymQuLemlGRm872nZ8yeDMteFfqpeBq9Tkm2tkzTWGOcffkH2fORpOTmbxEx5xpRJLMvS8JzMgqfZkxMyuv+snPrmy7L7Fx+UJz59SkYxZadgNxc82adfOCIvQycv8IWaFuiNH7epW5Cxr8H+6qqlGmHx5J5D8vzfvixji0lJ6a95xxH0jRiWixe3RxJfavsQuqTUDZnCrQXuA/JYmqMMoF3+RpM2PIsLDC/474C1gtrNpg2HM34LnMmThNFzR493nFKz4EbrMSFBvh0mMWbiAk1rQhldNCGFX7Q8zneJCbQD50zygxMLqAPKplzmTlg6U0+aL13qi6bFGnRDJj9j2mbKUkdCigEQ73nfKMj7/JGjZA3bMnn5Gc5EA+aSCZNH22kEv24gQVAPaMM8c8Ng14rwGgOc+bZCUw8fQajOCMyKRm+mnQKMJYk8+Xm0Pce0OCAvvyWQM6AD1sS9f6cF1I829Ptv3DJI8751UNMxw6fgzEzJY5DOc8mCQbkw5ufJY3BJ82teI785kmA66u6CMxRTuPxCenYZ/WnKuX3G/PqtjGhbewu3stw407yGllCf7Sd+KV5+wsim98ET+yBBHSuvVvcGRiLkbQXv/oIcA6NJZw62z4GM4AfB+QNSKvt5M9FpOyifykRL7YO77tQ/d679vOqoznURRjkolqCjmuuKQYahj4sqq6KZB0Vh2BR7VP48GZhmfpUOYqHxlONoLky9/NJGGIR+81QwD69SiHvJhQstpVXiTsQaztSqt2EwRnOlubx8KG/5DrfPla8dSIioOopANv5kJpbTHozu4kpZHuPqpNRqKHb73kILlOoqCLZN3vWNVb12s1s+V5QnBOYlJ3x8oUAd+vuzXsUqj2NnTOW3QpgvL0dmdkYkUCL0HqLKzkiQg0xcMQ/arjl1YOSPb3NlaPuIIMLf8pD4Suv/0ihF4dwjE/zZvgJGGd0cKAEScc9892c0Uwko0/zs4sUAddLLQ6V55XaKXpvTIviCQjZVkDQyUoYo/pjKjjfcRfNfoANz0RC6zR9/Qkwo/HmEeGdlNMIPdhUw9pr2AkC55aVl80Fp2F8i8DCQCOptJccif+6AyDbZOn/SIg4ULc5hmJbjQKQ8OcIrE7wOpRfh36NPmbrBCxqjmNQDB1DtVp6bQySUB3OqcPNy6LO/rG7h3lddYFrlYEN3DrBrM+KaXcef8NeTIqg52A3Kc1hQ84kASwT6pFi/0T2fR18MWKd+zNJcFqGPDfVtsaDcgDExmosJgsLEzuZXp9AIS++bibuk0spBJVIbHll9WPCa/eCS/hwHmtZjxH0Syxky43IpUXL7Z5s35/xdmDgnJViebVgN8JyKD9SPzkhh/cefmkil1ZxK4Oa3PK8GcmT3Q1RWJEQR7ZzHuHb15xZzGG74jNWSvgRBqXy+oshwQQcw2uXjBf7xyOsk0s18GFWaxKeXrt6DMOWCcEvT0TjIVHGSgIFyXFU7pbyQm8Rz6oBHY8OGiraBdD0PNx4C8/Kf/lZqsZNMIa2nQrJtarsOYayDU7FTcG1g7mgh9DjPzKOAoECrEfOXI2gsKijnCmpRVHQEETyat4/QrRHEcJiBcR4Gat8asT8joWNHjJNaGI0xfxzBaGExdGX+7IEJdN37wfqVX+8YhRKn867jqOis3nUYJo+xjSIxbUViHvNmmzq0zgDGOc0RzqovU5hzpkUTLYhl4xHVZ0WCveo3+nl5+TgYTepbTqYP4+HqQm0I2cMrAEL141EQ7De2YWSunFiWdQSBwcZmYMXByrl5leROJHfdOB2TnJwrEeEKWjGxXCm/Bki3bYTBdKvAuDwWNm9cPjZPh7Tk/wZseaCx0njNak2HPKRaom6hVxB5KM1T2mGx/CIb9aU/sIRLzaPFg+VdrCY7wXulRB49R4y5T4a4B2jlMzDpvE857XU0lcoeRtQ39blwB1J9KqLg2s/yUx6KAz6OVkYLe857+stzIGOz/EcZ2BuVkh2ktKIikAqHpGewlyMLYVoFR/wtSPt1kjpakXB3NegvU6PNiyKWN9X4QDoVQnbj2me6f680F1Ns3e55GH4aGg0ozl6vTrZ+atNt06+bejRrKc4zdkB08/l5zXmcXvQejgz52XPcPSzJ50DvkU2A5yvlNWBmGlG0MbmIq0trcIqtxl8kQT98hul/F66vL4KbdBxQDZk0jhcu2bwrodge+FVHRF1qd16dBO+zPzSEBvGc5A+4lVA8oHE/oxklDZm0UGdQITa8sE7r3YqCFYJyFYWugBQxN7wDjj7/pYT7nmJVuSZJwfJGocFzF2Y29MPTJLyAZFxqNaLujP5s/WTBOJBtz/JJPTJq4drK+0FcnNPR/Lw+XH4DhKp0ZgUVz0N5XHDSYR67Tgu3Ew3yS7lYgkdeB8E6ouoyL50jdgCp8SMtrk3eW4m4HKuCHaZBNuJz75uIAlMp2mHoS1aZ5hIHNdc+1EZ4VN641+LwRzGZH6RpPPfuuX5j6PsP8qIM2BGjOGroDR5jml3FSb8f4Bscygx/udiS7gwY4ixkNiiQp4RMeEZns2ss7TwF6lWFmvtWwe45Q1Eqhz+BwL3bKpTnt+InsNjhp0uUYHBxlMrTzSz8+ouGhHNj6CSeIzcO/El/cs8NF2M8kA6UArl/mgdEo3GJKtPqPJCHwH2Qhd5jm2CBbYHtkjzRYAPkmxxY/oOw7YbrYkiq9ygb2zbJerS0Gty8JDthkIxejLb5BJ1RLx87c1CirC4Vdeik6aClj+VoV+a/3fgq/qFv+GopPydr+oU1WYrWx8XAlZF8GrBuj3jD7NiZrx/mWSyopFWd1qm8bMKYxoU/Nx4c8hVCFUafGzJGZFRt08An5HLz8Z51dntuCLMo+GBuS+xtHpMYqUna+7HEjQtryIbs2g43QfBIJjuAGvVpFw3P7KhzlmBYbIYG88crkplBjFQ+0TmYxqNansrgkx2MDA9eGvi1m0WmbDCPoTCYRgGsjKV5LD88EsojhfTO7czPGixFObcL3gvnM2lmVqXu4DvQn7FJS7rHgJEoh5tZ2pKWMfeY3ycOptwQo8aNLfDPvVZ7ShhSm/GOhtgz7Ge/7crI8O3qhJT4asvv6kRj1cywVoHc7C7dJkdooVYUBg3SnOhbHVwbeFf4s93I4NGvvzIYkykCp+ZlBu/ag63bb4cZjClzdrMZ9MA6IGKYH16zvIUxafIe4gGgsbHjiw/gI8D68hyedfPCL0/92rao6WCbpm4DHPl2gFeW9yzMuXmWyNr0BQwPvEd+Oci67bqw7bt1Krwm+Xw1yBvriavP3jMubvMYCzBw2ylp15NXeUJx9i3NnRyY+MPct9A7+MclWJB/3jEp/M91el53eU0Kd3z5rYlszu72E2Zz0K9Jy3pkU3l0+6mk39i0io4TDs765ompvzKYoZQDA0YahytU+9XW39NoSRtGQ0VHBYyjgoOi8awAaIT1kPjKNY+syY5BbqPloSi9XhHKp3cZfhCt98wpYMqaRwHI6DaOW/Z5V5gn95pjIucv4wo+Dy7MI5twLR6gM76jyqPNQSd0HZWw9zSNPLEI/lLKNwebIGxZmB7a99zBkUcHVqapqcXDrycE1oOmeS+oYuY0QWAJaKn0Mu+e1h1Su0Wg3VBVphrqyzipjT9csIiGunGTB8AyeVSWRwhruycBW+CuPS8LaIP7AXGg5nS96sEZL7W8q7fitd5X7nDBwk6higC+MbgnuAZ1kPiKOqoRgG+juI5KcFapHKY+luQrEyuN7vEwQoedRBWEpJVmVmagm2ks42rZgsk4rGxMl+ioBJ0UzasDmkt9d5lHU8qvV2cxLy+RhBMWUJjDnAtekWjIJY+KbB16YeRegTu95xqdgu2jqDqNSQFsIlp2HDIApzN4ap09qn1tl3kiqjI80X4Yi0Xzr0VC5XywDLWGfgsYCJ+Fe6daq3MPfIRfSdRAzGs8zKvh0Qc9xtWVWUS4bVcAGIe+Ix16jJTkj88Uf+MCwhjhrDkYc2XTlZHPJo8U5GIoSly99jTljnqEbTdcpgQob+tZNe9qcBsNE3Whvx1j9KLrJKyP7O6n1ZcygnucAXTTi0WRZl6C8PVv6zEr1Cw6D3pyiJMMVaJ7bThelLmwGU+3dnORg0aSYTZGthTW3mZNi/pdUr4MBeRaiTSWCxL5ZR0GpfdJ+gceookOCqZLXmzAsAsl6XNrbkq6dUDvXEawX/hbPGyGOSxRPrvhpoRr6tfqGEnONWVg20y9GGJjlJN1WMrJ/wMaWv+GDrvEDQAAAABJRU5ErkJggg==', 300);
INSERT INTO "public"."users" VALUES (19, 'lawrence reyes', 'law@gmail.com', '$2a$10$8OnEAJvgmbBZPXVkuOpKHOK3SF0CxWKA9i6ePUsaLUcY81qfL2Wsq', 'Supervisor', 'Pending', '2025-11-27 01:55:56.386536', '1234', NULL, NULL, 'Female', '0955671', 'Office: it department
Position: ito
Location: zamboanga', NULL, NULL);
INSERT INTO "public"."users" VALUES (20, 'loyd caacac', 'caca@gmail.com', '$2a$10$ogOk/TWX.oVqg1JRtuaAgumJIKyR/W08nGuBXFCruXnmh7cyiJUWC', 'Coordinator', 'Pending', '2025-11-27 01:57:49.599562', '1235', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "public"."users" VALUES (7, 'lloyd momo', 'admin@jrmsu.edu.ph', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'Admin', 'Active', '2025-11-24 03:45:48.037303', NULL, NULL, NULL, NULL, '09123456789', 'JRMSU Main Campus, Dapitan City', NULL, 300);

-- ----------------------------
-- Function structure for auto_complete_ojt_record
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."auto_complete_ojt_record"("p_record_id" int4);
CREATE OR REPLACE FUNCTION "public"."auto_complete_ojt_record"("p_record_id" int4)
  RETURNS "pg_catalog"."bool" AS $BODY$
DECLARE
    v_student_id INT;
    v_required_hours NUMERIC;
    v_completed_hours NUMERIC;
    v_completion_pct NUMERIC;
BEGIN
    -- Get OJT record details
    SELECT 
        student_id,
        required_hours,
        (SELECT completion_percentage FROM get_student_progress(student_id))
    INTO v_student_id, v_required_hours, v_completion_pct
    FROM ojt_records
    WHERE record_id = p_record_id;
    
    -- Check if completion criteria met
    IF v_completion_pct >= 100 THEN
        -- Update status to Completed
        UPDATE ojt_records
        SET 
            status = 'Completed',
            end_date = COALESCE(end_date, CURRENT_DATE),
            updated_at = CURRENT_TIMESTAMP
        WHERE record_id = p_record_id;
        
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for calculate_attendance_hours
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."calculate_attendance_hours"();
CREATE OR REPLACE FUNCTION "public"."calculate_attendance_hours"()
  RETURNS "pg_catalog"."trigger" AS $BODY$
DECLARE
    total_hours_calc NUMERIC(5,2) := 0;
BEGIN
    IF NEW.morning_in IS NOT NULL AND NEW.morning_out IS NOT NULL THEN
        total_hours_calc := total_hours_calc + EXTRACT(EPOCH FROM (NEW.morning_out - NEW.morning_in)) / 3600;
    END IF;
    IF NEW.afternoon_in IS NOT NULL AND NEW.afternoon_out IS NOT NULL THEN
        total_hours_calc := total_hours_calc + EXTRACT(EPOCH FROM (NEW.afternoon_out - NEW.afternoon_in)) / 3600;
    END IF;
    IF NEW.overtime_in IS NOT NULL AND NEW.overtime_out IS NOT NULL THEN
        total_hours_calc := total_hours_calc + EXTRACT(EPOCH FROM (NEW.overtime_out - NEW.overtime_in)) / 3600;
    END IF;

    IF total_hours_calc > 0 THEN
        NEW.total_hours := total_hours_calc;
    ELSIF NEW.time_in IS NOT NULL AND NEW.time_out IS NOT NULL THEN
        NEW.total_hours := EXTRACT(EPOCH FROM (NEW.time_out - NEW.time_in)) / 3600;
    END IF;

    RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for calculate_risk_score
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."calculate_risk_score"("p_student_id" int4);
CREATE OR REPLACE FUNCTION "public"."calculate_risk_score"("p_student_id" int4)
  RETURNS TABLE("student_id" int4, "risk_score" numeric, "risk_level" varchar, "risk_factors" jsonb, "recommendations" _text) AS $BODY$
DECLARE
    v_attendance_rate NUMERIC;
    v_avg_score NUMERIC;
    v_hours_completion NUMERIC;
    v_recent_attendance NUMERIC;
    v_score NUMERIC := 0;
    v_level VARCHAR(20);
    v_factors JSONB := '[]'::JSONB;
    v_recommendations TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Calculate attendance rate (last 30 days)
    SELECT 
        COUNT(DISTINCT date)::NUMERIC / NULLIF(
            GREATEST((CURRENT_DATE - o.start_date), 1), 0
        ) * 100
    INTO v_recent_attendance
    FROM attendance a
    JOIN ojt_records o ON a.student_id = o.student_id
    WHERE a.student_id = p_student_id 
        AND a.date >= CURRENT_DATE - INTERVAL '30 days'
        AND o.status = 'Ongoing'
    GROUP BY o.start_date;
    
    -- Get average evaluation score
    SELECT COALESCE(AVG(total_score), 0)
    INTO v_avg_score
    FROM evaluations
    WHERE student_id = p_student_id;
    
    -- Get hours completion percentage
    SELECT completion_percentage
    INTO v_hours_completion
    FROM get_student_progress(p_student_id);
    
    -- Calculate risk score (0-100, higher = more risk)
    IF v_recent_attendance < 70 THEN
        v_score := v_score + 30;
        v_factors := v_factors || jsonb_build_object('factor', 'Low Attendance', 'value', v_recent_attendance);
        v_recommendations := v_recommendations || 'Improve attendance consistency';
    END IF;
    
    IF v_avg_score < 75 THEN
        v_score := v_score + 25;
        v_factors := v_factors || jsonb_build_object('factor', 'Low Evaluation Score', 'value', v_avg_score);
        v_recommendations := v_recommendations || 'Focus on improving performance metrics';
    END IF;
    
    IF v_hours_completion < 50 AND (SELECT EXTRACT(EPOCH FROM (CURRENT_DATE - start_date)) / 86400 FROM ojt_records WHERE student_id = p_student_id AND status = 'Ongoing' LIMIT 1) > 60 THEN
        v_score := v_score + 25;
        v_factors := v_factors || jsonb_build_object('factor', 'Slow Progress', 'value', v_hours_completion);
        v_recommendations := v_recommendations || 'Increase weekly hours to meet requirements';
    END IF;
    
    -- Determine risk level
    IF v_score >= 60 THEN
        v_level := 'High';
    ELSIF v_score >= 40 THEN
        v_level := 'Medium';
    ELSIF v_score >= 20 THEN
        v_level := 'Low';
    ELSE
        v_level := 'Minimal';
    END IF;
    
    RETURN QUERY SELECT 
        p_student_id,
        v_score,
        v_level,
        v_factors,
        v_recommendations;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;

-- ----------------------------
-- Function structure for create_ai_insight
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."create_ai_insight"("p_student_id" int4, "p_model_name" varchar, "p_insight_type" varchar, "p_result" jsonb, "p_confidence" numeric, "p_input_data" jsonb);
CREATE OR REPLACE FUNCTION "public"."create_ai_insight"("p_student_id" int4, "p_model_name" varchar, "p_insight_type" varchar, "p_result" jsonb, "p_confidence" numeric=NULL::numeric, "p_input_data" jsonb=NULL::jsonb)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_insight_id INT;
    v_result JSONB;
BEGIN
    INSERT INTO ai_insights (
        student_id, model_name, insight_type, result, confidence, input_data
    )
    VALUES (
        p_student_id, p_model_name, p_insight_type, p_result, p_confidence, p_input_data
    )
    RETURNING insight_id INTO v_insight_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'insight_id', v_insight_id,
        'message', 'AI insight created successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'insight_id', NULL
        );
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for create_attendance
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."create_attendance"("p_student_id" int4, "p_date" date, "p_time_in" time, "p_time_out" time, "p_morning_in" time, "p_morning_out" time, "p_afternoon_in" time, "p_afternoon_out" time);
CREATE OR REPLACE FUNCTION "public"."create_attendance"("p_student_id" int4, "p_date" date, "p_time_in" time, "p_time_out" time=NULL::time without time zone, "p_morning_in" time=NULL::time without time zone, "p_morning_out" time=NULL::time without time zone, "p_afternoon_in" time=NULL::time without time zone, "p_afternoon_out" time=NULL::time without time zone)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_attendance_id INT;
    v_validation JSONB;
    v_result JSONB;
BEGIN
    -- Validate attendance
    v_validation := validate_attendance(p_student_id, p_date, p_time_in, p_time_out);
    
    IF NOT (v_validation->>'is_valid')::BOOLEAN THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', v_validation->'errors',
            'attendance_id', NULL
        );
    END IF;
    
    -- Insert attendance
    INSERT INTO attendance (
        student_id, date, time_in, time_out,
        morning_in, morning_out, afternoon_in, afternoon_out
    )
    VALUES (
        p_student_id, p_date, p_time_in, p_time_out,
        p_morning_in, p_morning_out, p_afternoon_in, p_afternoon_out
    )
    RETURNING attendance_id INTO v_attendance_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'attendance_id', v_attendance_id,
        'message', 'Attendance recorded successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'attendance_id', NULL
        );
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for create_evaluation
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."create_evaluation"("p_student_id" int4, "p_supervisor_id" int4, "p_criteria" jsonb, "p_total_score" numeric, "p_feedback" text, "p_evaluation_period_start" date, "p_evaluation_period_end" date);
CREATE OR REPLACE FUNCTION "public"."create_evaluation"("p_student_id" int4, "p_supervisor_id" int4, "p_criteria" jsonb, "p_total_score" numeric, "p_feedback" text=NULL::text, "p_evaluation_period_start" date=NULL::date, "p_evaluation_period_end" date=NULL::date)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_eval_id INT;
    v_result JSONB;
BEGIN
    -- Validate score range
    IF p_total_score < 0 OR p_total_score > 100 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY['Total score must be between 0 and 100'],
            'eval_id', NULL
        );
    END IF;
    
    -- Insert evaluation
    INSERT INTO evaluations (
        student_id, supervisor_id, criteria, total_score,
        feedback, evaluation_period_start, evaluation_period_end, status
    )
    VALUES (
        p_student_id, p_supervisor_id, p_criteria, p_total_score,
        p_feedback, p_evaluation_period_start, p_evaluation_period_end, 'Draft'
    )
    RETURNING eval_id INTO v_eval_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'eval_id', v_eval_id,
        'message', 'Evaluation created successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'eval_id', NULL
        );
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for create_ojt_record
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."create_ojt_record"("p_student_id" int4, "p_company_name" varchar, "p_coordinator_id" int4, "p_supervisor_id" int4, "p_start_date" date, "p_end_date" date, "p_required_hours" int4, "p_company_address" text, "p_company_contact" varchar);
CREATE OR REPLACE FUNCTION "public"."create_ojt_record"("p_student_id" int4, "p_company_name" varchar, "p_coordinator_id" int4, "p_supervisor_id" int4, "p_start_date" date, "p_end_date" date=NULL::date, "p_required_hours" int4=300, "p_company_address" text=NULL::text, "p_company_contact" varchar=NULL::character varying)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_record_id INT;
    v_validation JSONB;
    v_result JSONB;
BEGIN
    -- Validate OJT record
    v_validation := validate_ojt_record(
        p_student_id,
        p_start_date,
        COALESCE(p_end_date, (p_start_date + INTERVAL '6 months')::DATE)
    );
    
    IF NOT (v_validation->>'is_valid')::BOOLEAN THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', v_validation->'errors',
            'record_id', NULL
        );
    END IF;
    
    -- Insert OJT record
    INSERT INTO ojt_records (
        student_id, company_name, coordinator_id, supervisor_id,
        start_date, end_date, required_hours, status,
        company_address, company_contact
    )
    VALUES (
        p_student_id, p_company_name, p_coordinator_id, p_supervisor_id,
        p_start_date, p_end_date, p_required_hours, 'Ongoing',
        p_company_address, p_company_contact
    )
    RETURNING record_id INTO v_record_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'record_id', v_record_id,
        'message', 'OJT record created successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'record_id', NULL
        );
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for create_system_report
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."create_system_report"("p_report_type" varchar, "p_generated_by" int4, "p_content" jsonb, "p_report_period_start" date, "p_report_period_end" date);
CREATE OR REPLACE FUNCTION "public"."create_system_report"("p_report_type" varchar, "p_generated_by" int4, "p_content" jsonb, "p_report_period_start" date=NULL::date, "p_report_period_end" date=NULL::date)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_report_id INT;
    v_result JSONB;
BEGIN
    INSERT INTO system_reports (
        report_type, generated_by, content,
        report_period_start, report_period_end, status
    )
    VALUES (
        p_report_type, p_generated_by, p_content,
        p_report_period_start, p_report_period_end, 'Generated'
    )
    RETURNING report_id INTO v_report_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'report_id', v_report_id,
        'message', 'Report created successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'report_id', NULL
        );
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for create_user
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."create_user"("p_full_name" varchar, "p_email" varchar, "p_password_hash" text, "p_role" varchar, "p_student_id" varchar, "p_course" varchar, "p_contact_number" varchar);
CREATE OR REPLACE FUNCTION "public"."create_user"("p_full_name" varchar, "p_email" varchar, "p_password_hash" text, "p_role" varchar, "p_student_id" varchar=NULL::character varying, "p_course" varchar=NULL::character varying, "p_contact_number" varchar=NULL::character varying)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_user_id INT;
    v_result JSONB;
    v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Validate email format
    IF p_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        v_errors := v_errors || 'Invalid email format';
    END IF;
    
    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        v_errors := v_errors || 'Email already exists';
    END IF;
    
    -- Validate role
    IF p_role NOT IN ('Admin', 'Coordinator', 'Supervisor', 'Student') THEN
        v_errors := v_errors || 'Invalid role';
    END IF;
    
    -- If errors, return them
    IF array_length(v_errors, 1) > 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', v_errors,
            'user_id', NULL
        );
    END IF;
    
    -- Insert user
    INSERT INTO users (
        full_name, email, password_hash, role, status,
        student_id, course, contact_number
    )
    VALUES (
        p_full_name, p_email, p_password_hash, p_role, 'Active',
        p_student_id, p_course, p_contact_number
    )
    RETURNING user_id INTO v_user_id;
    
    -- Return success with user data
    SELECT jsonb_build_object(
        'success', TRUE,
        'user_id', v_user_id,
        'user', jsonb_build_object(
            'user_id', v_user_id,
            'full_name', p_full_name,
            'email', p_email,
            'role', p_role,
            'status', 'Active'
        )
    ) INTO v_result;
    
    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'user_id', NULL
        );
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for delete_ai_insight
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."delete_ai_insight"("p_insight_id" int4);
CREATE OR REPLACE FUNCTION "public"."delete_ai_insight"("p_insight_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    DELETE FROM ai_insights
    WHERE insight_id = p_insight_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'AI insight deleted successfully',
        'insight_id', insight_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'AI insight not found'
        );
    END IF;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for delete_attendance
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."delete_attendance"("p_attendance_id" int4);
CREATE OR REPLACE FUNCTION "public"."delete_attendance"("p_attendance_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    DELETE FROM attendance
    WHERE attendance_id = p_attendance_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'Attendance record deleted successfully',
        'attendance_id', attendance_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Attendance record not found'
        );
    END IF;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for delete_evaluation
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."delete_evaluation"("p_eval_id" int4);
CREATE OR REPLACE FUNCTION "public"."delete_evaluation"("p_eval_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    DELETE FROM evaluations
    WHERE eval_id = p_eval_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'Evaluation deleted successfully',
        'eval_id', eval_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Evaluation not found'
        );
    END IF;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for delete_ojt_record
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."delete_ojt_record"("p_record_id" int4);
CREATE OR REPLACE FUNCTION "public"."delete_ojt_record"("p_record_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    DELETE FROM ojt_records
    WHERE record_id = p_record_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'OJT record deleted successfully',
        'record_id', record_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'OJT record not found'
        );
    END IF;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for delete_system_report
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."delete_system_report"("p_report_id" int4);
CREATE OR REPLACE FUNCTION "public"."delete_system_report"("p_report_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    DELETE FROM system_reports
    WHERE report_id = p_report_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'Report deleted successfully',
        'report_id', report_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Report not found'
        );
    END IF;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for delete_user
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."delete_user"("p_user_id" int4);
CREATE OR REPLACE FUNCTION "public"."delete_user"("p_user_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    -- Soft delete by setting status to 'Inactive'
    UPDATE users
    SET status = 'Inactive'
    WHERE user_id = p_user_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'User deactivated successfully',
        'user_id', user_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'User not found'
        );
    END IF;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for generate_batch_predictions
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."generate_batch_predictions"();
CREATE OR REPLACE FUNCTION "public"."generate_batch_predictions"()
  RETURNS TABLE("student_id" int4, "prediction_id" int4, "prediction_result" jsonb) AS $BODY$
DECLARE
    v_student RECORD;
    v_insight_id INT;
BEGIN
    -- Loop through all active students
    FOR v_student IN 
        SELECT DISTINCT u.user_id
        FROM users u
        JOIN ojt_records o ON u.user_id = o.student_id
        WHERE u.role = 'Student' AND o.status = 'Ongoing'
    LOOP
        -- Generate prediction
        INSERT INTO ai_insights (
            student_id,
            model_name,
            insight_type,
            result,
            confidence,
            input_data
        )
        SELECT 
            v_student.user_id,
            'Performance Prediction Model',
            'performance_prediction',
            generate_performance_prediction(v_student.user_id),
            (generate_performance_prediction(v_student.user_id)->>'confidence')::NUMERIC,
            jsonb_build_object(
                'generated_at', CURRENT_TIMESTAMP,
                'batch_job', TRUE
            )
        RETURNING insight_id INTO v_insight_id;
        
        -- Return result
        RETURN QUERY SELECT 
            v_student.user_id,
            v_insight_id,
            generate_performance_prediction(v_student.user_id);
    END LOOP;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;

-- ----------------------------
-- Function structure for generate_performance_prediction
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."generate_performance_prediction"("p_student_id" int4);
CREATE OR REPLACE FUNCTION "public"."generate_performance_prediction"("p_student_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_prediction JSONB;
    v_attendance_trend NUMERIC;
    v_evaluation_trend NUMERIC;
    v_current_score NUMERIC;
    v_predicted_score NUMERIC;
    v_confidence NUMERIC;
BEGIN
    -- Calculate attendance trend (comparing last 2 weeks vs previous 2 weeks)
    SELECT 
        (COUNT(CASE WHEN date >= CURRENT_DATE - INTERVAL '14 days' THEN 1 END)::NUMERIC / 14 * 100) -
        (COUNT(CASE WHEN date >= CURRENT_DATE - INTERVAL '28 days' AND date < CURRENT_DATE - INTERVAL '14 days' THEN 1 END)::NUMERIC / 14 * 100)
    INTO v_attendance_trend
    FROM attendance
    WHERE student_id = p_student_id;
    
    -- Calculate evaluation trend
    SELECT 
        COALESCE(
            (SELECT AVG(total_score) FROM evaluations 
             WHERE student_id = p_student_id 
             AND date_evaluated >= CURRENT_DATE - INTERVAL '30 days') -
            (SELECT AVG(total_score) FROM evaluations 
             WHERE student_id = p_student_id 
             AND date_evaluated >= CURRENT_DATE - INTERVAL '60 days' 
             AND date_evaluated < CURRENT_DATE - INTERVAL '30 days'),
            0
        )
    INTO v_evaluation_trend;
    
    -- Get current average score
    SELECT COALESCE(AVG(total_score), 75)
    INTO v_current_score
    FROM evaluations
    WHERE student_id = p_student_id;
    
    -- Simple prediction: current score + trend adjustment
    v_predicted_score := v_current_score + (v_evaluation_trend * 0.3) + (v_attendance_trend * 0.1);
    v_predicted_score := GREATEST(0, LEAST(100, v_predicted_score));
    
    -- Calculate confidence based on data availability
    SELECT 
        CASE 
            WHEN COUNT(*) >= 3 THEN 0.85
            WHEN COUNT(*) >= 1 THEN 0.70
            ELSE 0.50
        END
    INTO v_confidence
    FROM evaluations
    WHERE student_id = p_student_id;
    
    -- Build prediction result
    v_prediction := jsonb_build_object(
        'student_id', p_student_id,
        'predicted_performance', ROUND(v_predicted_score, 2),
        'current_performance', ROUND(v_current_score, 2),
        'attendance_trend', ROUND(v_attendance_trend, 2),
        'evaluation_trend', ROUND(v_evaluation_trend, 2),
        'confidence', ROUND(v_confidence, 2),
        'prediction_date', CURRENT_TIMESTAMP,
        'risk_assessment', (SELECT jsonb_build_object(
            'risk_score', risk_score,
            'risk_level', risk_level,
            'risk_factors', risk_factors
        ) FROM calculate_risk_score(p_student_id))
    );
    
    RETURN v_prediction;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for generate_student_progress_report
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."generate_student_progress_report"("p_student_id" int4, "p_generated_by" int4, "p_report_period_start" date, "p_report_period_end" date);
CREATE OR REPLACE FUNCTION "public"."generate_student_progress_report"("p_student_id" int4, "p_generated_by" int4, "p_report_period_start" date=NULL::date, "p_report_period_end" date=NULL::date)
  RETURNS "pg_catalog"."int4" AS $BODY$
DECLARE
    v_report_id INT;
    v_start_date DATE := COALESCE(p_report_period_start, (SELECT start_date FROM ojt_records WHERE student_id = p_student_id AND status = 'Ongoing' LIMIT 1));
    v_end_date DATE := COALESCE(p_report_period_end, CURRENT_DATE);
    v_report_content JSONB;
BEGIN
    -- Build comprehensive report content
    v_report_content := jsonb_build_object(
        'student_info', (SELECT jsonb_build_object(
            'user_id', user_id,
            'full_name', full_name,
            'student_id', student_id,
            'course', course,
            'email', email
        ) FROM users WHERE user_id = p_student_id),
        'ojt_info', (SELECT jsonb_build_object(
            'company_name', company_name,
            'start_date', start_date,
            'end_date', end_date,
            'status', status,
            'required_hours', required_hours
        ) FROM ojt_records WHERE student_id = p_student_id AND status = 'Ongoing' LIMIT 1),
        'progress', (SELECT * FROM get_student_progress(p_student_id)),
        'attendance_stats', get_attendance_statistics(p_student_id, v_start_date, v_end_date),
        'evaluations', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'eval_id', eval_id,
                    'supervisor_id', supervisor_id,
                    'total_score', total_score,
                    'date_evaluated', date_evaluated,
                    'feedback', feedback
                )
                ORDER BY date_evaluated DESC
            )
            FROM evaluations
            WHERE student_id = p_student_id
            AND date_evaluated BETWEEN v_start_date AND v_end_date
        ),
        'ai_insights', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'insight_type', insight_type,
                    'result', result,
                    'confidence', confidence,
                    'created_at', created_at
                )
                ORDER BY created_at DESC
            )
            FROM ai_insights
            WHERE student_id = p_student_id
            AND created_at::DATE BETWEEN v_start_date AND v_end_date
        ),
        'risk_assessment', (SELECT jsonb_build_object(
            'risk_score', risk_score,
            'risk_level', risk_level,
            'risk_factors', risk_factors,
            'recommendations', recommendations
        ) FROM calculate_risk_score(p_student_id)),
        'generated_at', CURRENT_TIMESTAMP
    );
    
    -- Insert report
    INSERT INTO system_reports (
        report_type,
        generated_by,
        content,
        report_period_start,
        report_period_end,
        status
    ) VALUES (
        'Student Progress Report',
        p_generated_by,
        v_report_content,
        v_start_date,
        v_end_date,
        'Generated'
    ) RETURNING report_id INTO v_report_id;
    
    RETURN v_report_id;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for get_ai_insight
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."get_ai_insight"("p_insight_id" int4);
CREATE OR REPLACE FUNCTION "public"."get_ai_insight"("p_insight_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'insight_id', ai.insight_id,
        'student_id', ai.student_id,
        'student_name', u.full_name,
        'model_name', ai.model_name,
        'insight_type', ai.insight_type,
        'result', ai.result,
        'confidence', ai.confidence,
        'input_data', ai.input_data,
        'created_at', ai.created_at
    ) INTO v_result
    FROM ai_insights ai
    JOIN users u ON ai.student_id = u.user_id
    WHERE ai.insight_id = p_insight_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'AI insight not found'));
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for get_at_risk_students
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."get_at_risk_students"("p_risk_level" varchar);
CREATE OR REPLACE FUNCTION "public"."get_at_risk_students"("p_risk_level" varchar='Medium'::character varying)
  RETURNS TABLE("student_id" int4, "full_name" varchar, "student_id_number" varchar, "course" varchar, "company_name" varchar, "risk_score" numeric, "risk_level" varchar, "risk_factors" jsonb, "recommendations" _text) AS $BODY$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.full_name,
        u.student_id,
        u.course,
        o.company_name,
        rs.risk_score,
        rs.risk_level,
        rs.risk_factors,
        rs.recommendations
    FROM users u
    JOIN ojt_records o ON u.user_id = o.student_id AND o.status = 'Ongoing'
    CROSS JOIN LATERAL calculate_risk_score(u.user_id) rs
    WHERE u.role = 'Student'
    AND (
        CASE p_risk_level
            WHEN 'High' THEN rs.risk_level = 'High'
            WHEN 'Medium' THEN rs.risk_level IN ('High', 'Medium')
            ELSE TRUE
        END
    )
    ORDER BY rs.risk_score DESC;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;

-- ----------------------------
-- Function structure for get_attendance
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."get_attendance"("p_attendance_id" int4);
CREATE OR REPLACE FUNCTION "public"."get_attendance"("p_attendance_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'attendance_id', a.attendance_id,
        'student_id', a.student_id,
        'student_name', u.full_name,
        'date', a.date,
        'time_in', a.time_in,
        'time_out', a.time_out,
        'total_hours', a.total_hours,
        'morning_in', a.morning_in,
        'morning_out', a.morning_out,
        'afternoon_in', a.afternoon_in,
        'afternoon_out', a.afternoon_out,
        'verified', a.verified,
        'created_at', a.created_at
    ) INTO v_result
    FROM attendance a
    JOIN users u ON a.student_id = u.user_id
    WHERE a.attendance_id = p_attendance_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'Attendance record not found'));
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for get_attendance_statistics
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."get_attendance_statistics"("p_student_id" int4, "p_start_date" date, "p_end_date" date);
CREATE OR REPLACE FUNCTION "public"."get_attendance_statistics"("p_student_id" int4, "p_start_date" date=NULL::date, "p_end_date" date=NULL::date)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
    v_start DATE := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
    v_end DATE := COALESCE(p_end_date, CURRENT_DATE);
BEGIN
    SELECT jsonb_build_object(
        'period', jsonb_build_object(
            'start_date', v_start,
            'end_date', v_end
        ),
        'summary', jsonb_build_object(
            'total_days', COUNT(DISTINCT a.date),
            'total_hours', COALESCE(SUM(a.total_hours), 0),
            'avg_hours_per_day', COALESCE(AVG(a.total_hours), 0),
            'max_hours_day', COALESCE(MAX(a.total_hours), 0),
            'min_hours_day', COALESCE(MIN(a.total_hours), 0),
            'verified_days', COUNT(CASE WHEN a.verified THEN 1 END),
            'unverified_days', COUNT(CASE WHEN NOT a.verified THEN 1 END)
        ),
        'daily_breakdown', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'date', a.date,
                    'time_in', a.time_in,
                    'time_out', a.time_out,
                    'total_hours', a.total_hours,
                    'verified', a.verified
                )
                ORDER BY a.date DESC
            )
            FROM attendance a
            WHERE a.student_id = p_student_id
            AND a.date BETWEEN v_start AND v_end
        ),
        'weekly_summary', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'week_start', week_start,
                    'week_end', week_end,
                    'total_hours', week_hours,
                    'days_present', days_count
                )
            )
            FROM (
                SELECT 
                    DATE_TRUNC('week', a.date)::DATE AS week_start,
                    (DATE_TRUNC('week', a.date) + INTERVAL '6 days')::DATE AS week_end,
                    SUM(a.total_hours) AS week_hours,
                    COUNT(DISTINCT a.date) AS days_count
                FROM attendance a
                WHERE a.student_id = p_student_id
                AND a.date BETWEEN v_start AND v_end
                GROUP BY DATE_TRUNC('week', a.date)
                ORDER BY week_start DESC
            ) weekly_data
        )
    ) INTO v_result
    FROM attendance a
    WHERE a.student_id = p_student_id
    AND a.date BETWEEN v_start AND v_end;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for get_evaluation
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."get_evaluation"("p_eval_id" int4);
CREATE OR REPLACE FUNCTION "public"."get_evaluation"("p_eval_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'eval_id', e.eval_id,
        'student_id', e.student_id,
        'student_name', s.full_name,
        'supervisor_id', e.supervisor_id,
        'supervisor_name', sup.full_name,
        'criteria', e.criteria,
        'total_score', e.total_score,
        'feedback', e.feedback,
        'status', e.status,
        'date_evaluated', e.date_evaluated,
        'evaluation_period_start', e.evaluation_period_start,
        'evaluation_period_end', e.evaluation_period_end
    ) INTO v_result
    FROM evaluations e
    JOIN users s ON e.student_id = s.user_id
    JOIN users sup ON e.supervisor_id = sup.user_id
    WHERE e.eval_id = p_eval_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'Evaluation not found'));
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for get_ojt_record
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."get_ojt_record"("p_record_id" int4);
CREATE OR REPLACE FUNCTION "public"."get_ojt_record"("p_record_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'record_id', o.record_id,
        'student_id', o.student_id,
        'student_name', s.full_name,
        'company_name', o.company_name,
        'coordinator_id', o.coordinator_id,
        'coordinator_name', c.full_name,
        'supervisor_id', o.supervisor_id,
        'supervisor_name', sup.full_name,
        'start_date', o.start_date,
        'end_date', o.end_date,
        'status', o.status,
        'required_hours', o.required_hours,
        'company_address', o.company_address,
        'company_contact', o.company_contact,
        'created_at', o.created_at
    ) INTO v_result
    FROM ojt_records o
    JOIN users s ON o.student_id = s.user_id
    JOIN users c ON o.coordinator_id = c.user_id
    JOIN users sup ON o.supervisor_id = sup.user_id
    WHERE o.record_id = p_record_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'OJT record not found'));
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for get_student_analytics
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."get_student_analytics"("p_student_id" int4);
CREATE OR REPLACE FUNCTION "public"."get_student_analytics"("p_student_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'student_info', (
            SELECT jsonb_build_object(
                'user_id', u.user_id,
                'full_name', u.full_name,
                'student_id', u.student_id,
                'course', u.course,
                'email', u.email
            )
            FROM users u
            WHERE u.user_id = p_student_id
        ),
        'ojt_info', (
            SELECT jsonb_build_object(
                'company_name', o.company_name,
                'start_date', o.start_date,
                'end_date', o.end_date,
                'status', o.status,
                'required_hours', o.required_hours
            )
            FROM ojt_records o
            WHERE o.student_id = p_student_id AND o.status = 'Ongoing'
            LIMIT 1
        ),
        'attendance_stats', (
            SELECT jsonb_build_object(
                'total_days', COUNT(DISTINCT a.date),
                'total_hours', COALESCE(SUM(a.total_hours), 0),
                'avg_hours_per_day', COALESCE(AVG(a.total_hours), 0),
                'verified_days', COUNT(CASE WHEN a.verified THEN 1 END),
                'last_attendance', MAX(a.date)
            )
            FROM attendance a
            WHERE a.student_id = p_student_id
        ),
        'evaluation_stats', (
            SELECT jsonb_build_object(
                'total_evaluations', COUNT(*),
                'avg_score', COALESCE(AVG(e.total_score), 0),
                'latest_score', (
                    SELECT total_score 
                    FROM evaluations 
                    WHERE student_id = p_student_id 
                    ORDER BY date_evaluated DESC 
                    LIMIT 1
                ),
                'latest_evaluation_date', MAX(e.date_evaluated)
            )
            FROM evaluations e
            WHERE e.student_id = p_student_id
        ),
        'ai_insights', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'insight_type', ai.insight_type,
                    'prediction', ai.result->>'predicted_performance',
                    'risk_level', ai.result->>'risk_level',
                    'confidence', ai.confidence,
                    'created_at', ai.created_at
                )
            )
            FROM ai_insights ai
            WHERE ai.student_id = p_student_id
            ORDER BY ai.created_at DESC
            LIMIT 5
        ),
        'progress', (
            SELECT * FROM get_student_progress(p_student_id)
        )
    ) INTO result;
    
    RETURN result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for get_student_progress
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."get_student_progress"("p_student_id" int4);
CREATE OR REPLACE FUNCTION "public"."get_student_progress"("p_student_id" int4)
  RETURNS TABLE("student_id" int4, "full_name" varchar, "required_hours" numeric, "completed_hours" numeric, "completion_percentage" numeric, "attendance_days" int4, "remaining_hours" numeric, "estimated_completion_date" date) AS $BODY$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.full_name,
        COALESCE(o.required_hours, u.required_hours, 300)::NUMERIC AS req_hours,
        COALESCE(SUM(a.total_hours), 0)::NUMERIC AS comp_hours,
        ROUND(
            (COALESCE(SUM(a.total_hours), 0)::NUMERIC / 
             NULLIF(COALESCE(o.required_hours, u.required_hours, 300), 0) * 100), 
            2
        ) AS completion_pct,
        COUNT(DISTINCT a.date)::INT AS att_days,
        GREATEST(
            (COALESCE(o.required_hours, u.required_hours, 300) - COALESCE(SUM(a.total_hours), 0))::NUMERIC,
            0
        ) AS rem_hours,
        CASE 
            WHEN AVG(a.total_hours) > 0 AND o.end_date IS NULL THEN
                CURRENT_DATE + INTERVAL '1 day' * 
                CEIL((COALESCE(o.required_hours, u.required_hours, 300) - COALESCE(SUM(a.total_hours), 0)) / AVG(a.total_hours))
            ELSE o.end_date
        END AS est_completion
    FROM users u
    LEFT JOIN ojt_records o ON u.user_id = o.student_id AND o.status = 'Ongoing'
    LEFT JOIN attendance a ON u.user_id = a.student_id
    WHERE u.user_id = p_student_id AND u.role = 'Student'
    GROUP BY u.user_id, u.full_name, o.required_hours, u.required_hours, o.end_date;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;

-- ----------------------------
-- Function structure for get_system_report
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."get_system_report"("p_report_id" int4);
CREATE OR REPLACE FUNCTION "public"."get_system_report"("p_report_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'report_id', r.report_id,
        'report_type', r.report_type,
        'generated_by', r.generated_by,
        'generated_by_name', u.full_name,
        'content', r.content,
        'status', r.status,
        'report_period_start', r.report_period_start,
        'report_period_end', r.report_period_end,
        'created_at', r.created_at
    ) INTO v_result
    FROM system_reports r
    JOIN users u ON r.generated_by = u.user_id
    WHERE r.report_id = p_report_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'Report not found'));
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for get_system_statistics
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."get_system_statistics"();
CREATE OR REPLACE FUNCTION "public"."get_system_statistics"()
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'students', jsonb_build_object(
            'total_students', (SELECT COUNT(*) FROM users WHERE role = 'Student'),
            'active_ojt', (SELECT COUNT(*) FROM ojt_records WHERE status = 'Ongoing'),
            'completed_ojt', (SELECT COUNT(*) FROM ojt_records WHERE status = 'Completed')
        ),
        'attendance', jsonb_build_object(
            'total_records', (SELECT COUNT(*) FROM attendance),
            'verified_records', (SELECT COUNT(*) FROM attendance WHERE verified = TRUE),
            'total_hours_logged', (SELECT COALESCE(SUM(total_hours), 0) FROM attendance)
        ),
        'evaluations', jsonb_build_object(
            'total_evaluations', (SELECT COUNT(*) FROM evaluations),
            'avg_score', (SELECT COALESCE(AVG(total_score), 0) FROM evaluations),
            'pending_approvals', (SELECT COUNT(*) FROM evaluations WHERE status = 'Draft')
        ),
        'ai_insights', jsonb_build_object(
            'total_insights', (SELECT COUNT(*) FROM ai_insights),
            'avg_confidence', (SELECT COALESCE(AVG(confidence), 0) FROM ai_insights),
            'latest_insight_date', (SELECT MAX(created_at) FROM ai_insights)
        ),
        'chatbot', jsonb_build_object(
            'total_interactions', (SELECT COUNT(*) FROM chatbot_logs),
            'unique_users', (SELECT COUNT(DISTINCT user_id) FROM chatbot_logs),
            'last_interaction', (SELECT MAX(timestamp) FROM chatbot_logs)
        ),
        'generated_at', CURRENT_TIMESTAMP
    ) INTO v_result;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for get_user
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."get_user"("p_user_id" int4);
CREATE OR REPLACE FUNCTION "public"."get_user"("p_user_id" int4)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'user_id', u.user_id,
        'full_name', u.full_name,
        'email', u.email,
        'role', u.role,
        'status', u.status,
        'student_id', u.student_id,
        'course', u.course,
        'contact_number', u.contact_number,
        'date_created', u.date_created
    ) INTO v_result
    FROM users u
    WHERE u.user_id = p_user_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'User not found'));
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for trigger_performance_prediction
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."trigger_performance_prediction"();
CREATE OR REPLACE FUNCTION "public"."trigger_performance_prediction"()
  RETURNS "pg_catalog"."trigger" AS $BODY$
BEGIN
    -- Generate and store prediction when new evaluation is added
    INSERT INTO ai_insights (
        student_id,
        model_name,
        insight_type,
        result,
        confidence,
        input_data
    )
    VALUES (
        NEW.student_id,
        'Auto Prediction Model',
        'performance_prediction',
        generate_performance_prediction(NEW.student_id),
        (generate_performance_prediction(NEW.student_id)->>'confidence')::NUMERIC,
        jsonb_build_object(
            'triggered_by', 'evaluation_insert',
            'eval_id', NEW.eval_id,
            'triggered_at', CURRENT_TIMESTAMP
        )
    );
    
    RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for update_attendance
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."update_attendance"("p_attendance_id" int4, "p_time_in" time, "p_time_out" time, "p_morning_in" time, "p_morning_out" time, "p_afternoon_in" time, "p_afternoon_out" time);
CREATE OR REPLACE FUNCTION "public"."update_attendance"("p_attendance_id" int4, "p_time_in" time=NULL::time without time zone, "p_time_out" time=NULL::time without time zone, "p_morning_in" time=NULL::time without time zone, "p_morning_out" time=NULL::time without time zone, "p_afternoon_in" time=NULL::time without time zone, "p_afternoon_out" time=NULL::time without time zone)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    UPDATE attendance SET
        time_in = COALESCE(p_time_in, time_in),
        time_out = COALESCE(p_time_out, time_out),
        morning_in = COALESCE(p_morning_in, morning_in),
        morning_out = COALESCE(p_morning_out, morning_out),
        afternoon_in = COALESCE(p_afternoon_in, afternoon_in),
        afternoon_out = COALESCE(p_afternoon_out, afternoon_out),
        updated_at = CURRENT_TIMESTAMP
    WHERE attendance_id = p_attendance_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'attendance_id', attendance_id,
        'total_hours', total_hours
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Attendance record not found'
        );
    END IF;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for update_evaluation
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."update_evaluation"("p_eval_id" int4, "p_criteria" jsonb, "p_total_score" numeric, "p_feedback" text, "p_status" varchar);
CREATE OR REPLACE FUNCTION "public"."update_evaluation"("p_eval_id" int4, "p_criteria" jsonb=NULL::jsonb, "p_total_score" numeric=NULL::numeric, "p_feedback" text=NULL::text, "p_status" varchar=NULL::character varying)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
BEGIN
    -- Validate score if provided
    IF p_total_score IS NOT NULL AND (p_total_score < 0 OR p_total_score > 100) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY['Total score must be between 0 and 100']
        );
    END IF;
    
    -- Update evaluation
    UPDATE evaluations SET
        criteria = COALESCE(p_criteria, criteria),
        total_score = COALESCE(p_total_score, total_score),
        feedback = COALESCE(p_feedback, feedback),
        status = COALESCE(p_status, status),
        updated_at = CURRENT_TIMESTAMP
    WHERE eval_id = p_eval_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'eval_id', eval_id,
        'status', status
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Evaluation not found'
        );
    END IF;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for update_ojt_record
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."update_ojt_record"("p_record_id" int4, "p_company_name" varchar, "p_start_date" date, "p_end_date" date, "p_status" varchar, "p_required_hours" int4, "p_company_address" text, "p_company_contact" varchar);
CREATE OR REPLACE FUNCTION "public"."update_ojt_record"("p_record_id" int4, "p_company_name" varchar=NULL::character varying, "p_start_date" date=NULL::date, "p_end_date" date=NULL::date, "p_status" varchar=NULL::character varying, "p_required_hours" int4=NULL::integer, "p_company_address" text=NULL::text, "p_company_contact" varchar=NULL::character varying)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
    v_student_id INT;
BEGIN
    -- Get student_id for validation
    SELECT student_id INTO v_student_id
    FROM ojt_records
    WHERE record_id = p_record_id;
    
    IF v_student_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'OJT record not found'
        );
    END IF;
    
    -- Update OJT record
    UPDATE ojt_records SET
        company_name = COALESCE(p_company_name, company_name),
        start_date = COALESCE(p_start_date, start_date),
        end_date = COALESCE(p_end_date, end_date),
        status = COALESCE(p_status, status),
        required_hours = COALESCE(p_required_hours, required_hours),
        company_address = COALESCE(p_company_address, company_address),
        company_contact = COALESCE(p_company_contact, company_contact),
        updated_at = CURRENT_TIMESTAMP
    WHERE record_id = p_record_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'record_id', record_id,
        'status', status
    ) INTO v_result;
    
    -- Auto-complete if criteria met
    IF p_status = 'Ongoing' OR p_status IS NULL THEN
        PERFORM auto_complete_ojt_record(p_record_id);
    END IF;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for update_updated_at_column
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."update_updated_at_column"();
CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"()
  RETURNS "pg_catalog"."trigger" AS $BODY$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for update_user
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."update_user"("p_user_id" int4, "p_full_name" varchar, "p_email" varchar, "p_role" varchar, "p_status" varchar, "p_student_id" varchar, "p_course" varchar, "p_contact_number" varchar);
CREATE OR REPLACE FUNCTION "public"."update_user"("p_user_id" int4, "p_full_name" varchar=NULL::character varying, "p_email" varchar=NULL::character varying, "p_role" varchar=NULL::character varying, "p_status" varchar=NULL::character varying, "p_student_id" varchar=NULL::character varying, "p_course" varchar=NULL::character varying, "p_contact_number" varchar=NULL::character varying)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
    v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY['User not found']
        );
    END IF;
    
    -- Validate email if provided
    IF p_email IS NOT NULL AND p_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        v_errors := v_errors || 'Invalid email format';
    END IF;
    
    -- Check email uniqueness if changed
    IF p_email IS NOT NULL AND EXISTS (
        SELECT 1 FROM users WHERE email = p_email AND user_id != p_user_id
    ) THEN
        v_errors := v_errors || 'Email already exists';
    END IF;
    
    IF array_length(v_errors, 1) > 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', v_errors
        );
    END IF;
    
    -- Update user
    UPDATE users SET
        full_name = COALESCE(p_full_name, full_name),
        email = COALESCE(p_email, email),
        role = COALESCE(p_role, role),
        status = COALESCE(p_status, status),
        student_id = COALESCE(p_student_id, student_id),
        course = COALESCE(p_course, course),
        contact_number = COALESCE(p_contact_number, contact_number)
    WHERE user_id = p_user_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'user_id', user_id,
        'full_name', full_name,
        'email', email,
        'role', role,
        'status', status
    ) INTO v_result;
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for validate_attendance
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."validate_attendance"("p_student_id" int4, "p_date" date, "p_time_in" time, "p_time_out" time);
CREATE OR REPLACE FUNCTION "public"."validate_attendance"("p_student_id" int4, "p_date" date, "p_time_in" time, "p_time_out" time=NULL::time without time zone)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
    v_is_valid BOOLEAN := TRUE;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_existing_count INT;
    v_ojt_status VARCHAR(20);
BEGIN
    -- Check if student has active OJT
    SELECT status INTO v_ojt_status
    FROM ojt_records
    WHERE student_id = p_student_id AND status = 'Ongoing'
    LIMIT 1;
    
    IF v_ojt_status IS NULL THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Student does not have an active OJT record';
    END IF;
    
    -- Check if date is within OJT period
    IF NOT EXISTS (
        SELECT 1 FROM ojt_records
        WHERE student_id = p_student_id
        AND status = 'Ongoing'
        AND p_date >= COALESCE(start_date, CURRENT_DATE - INTERVAL '1 year')
        AND p_date <= COALESCE(end_date, CURRENT_DATE + INTERVAL '1 year')
    ) THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Date is outside OJT period';
    END IF;
    
    -- Check for duplicate entry
    SELECT COUNT(*) INTO v_existing_count
    FROM attendance
    WHERE student_id = p_student_id AND date = p_date;
    
    IF v_existing_count > 0 THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Attendance already recorded for this date';
    END IF;
    
    -- Validate time range
    IF p_time_out IS NOT NULL AND p_time_in >= p_time_out THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Time out must be after time in';
    END IF;
    
    -- Check if date is in the future
    IF p_date > CURRENT_DATE THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Cannot record attendance for future dates';
    END IF;
    
    v_result := jsonb_build_object(
        'is_valid', v_is_valid,
        'errors', v_errors,
        'warnings', ARRAY[]::TEXT[]
    );
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Function structure for validate_ojt_record
-- ----------------------------
DROP FUNCTION IF EXISTS "public"."validate_ojt_record"("p_student_id" int4, "p_start_date" date, "p_end_date" date);
CREATE OR REPLACE FUNCTION "public"."validate_ojt_record"("p_student_id" int4, "p_start_date" date, "p_end_date" date)
  RETURNS "pg_catalog"."jsonb" AS $BODY$
DECLARE
    v_result JSONB;
    v_is_valid BOOLEAN := TRUE;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_existing_count INT;
BEGIN
    -- Check if student exists and is a student role
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_student_id AND role = 'Student') THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Invalid student ID or user is not a student';
    END IF;
    
    -- Check for overlapping OJT records
    SELECT COUNT(*) INTO v_existing_count
    FROM ojt_records
    WHERE student_id = p_student_id
    AND status = 'Ongoing'
    AND (
        (p_start_date BETWEEN start_date AND COALESCE(end_date, CURRENT_DATE + INTERVAL '1 year'))
        OR (p_end_date BETWEEN start_date AND COALESCE(end_date, CURRENT_DATE + INTERVAL '1 year'))
        OR (start_date BETWEEN p_start_date AND p_end_date)
    );
    
    IF v_existing_count > 0 THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Student already has an active OJT record with overlapping dates';
    END IF;
    
    -- Validate date range
    IF p_start_date >= p_end_date THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'End date must be after start date';
    END IF;
    
    -- Check if start date is too far in the past
    IF p_start_date < CURRENT_DATE - INTERVAL '2 years' THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Start date cannot be more than 2 years in the past';
    END IF;
    
    v_result := jsonb_build_object(
        'is_valid', v_is_valid,
        'errors', v_errors
    );
    
    RETURN v_result;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."ai_insights_insight_id_seq"
OWNED BY "public"."ai_insights"."insight_id";
SELECT setval('"public"."ai_insights_insight_id_seq"', 51, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."attendance_attendance_id_seq"
OWNED BY "public"."attendance"."attendance_id";
SELECT setval('"public"."attendance_attendance_id_seq"', 89, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."chatbot_logs_chat_id_seq"
OWNED BY "public"."chatbot_logs"."chat_id";
SELECT setval('"public"."chatbot_logs_chat_id_seq"', 39, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."evaluations_eval_id_seq"
OWNED BY "public"."evaluations"."eval_id";
SELECT setval('"public"."evaluations_eval_id_seq"', 3, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."ojt_records_record_id_seq"
OWNED BY "public"."ojt_records"."record_id";
SELECT setval('"public"."ojt_records_record_id_seq"', 5, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."system_reports_report_id_seq"
OWNED BY "public"."system_reports"."report_id";
SELECT setval('"public"."system_reports_report_id_seq"', 1, true);

-- ----------------------------
-- Alter sequences owned by
-- ----------------------------
ALTER SEQUENCE "public"."users_user_id_seq"
OWNED BY "public"."users"."user_id";
SELECT setval('"public"."users_user_id_seq"', 20, true);

-- ----------------------------
-- Primary Key structure for table ai_insights
-- ----------------------------
ALTER TABLE "public"."ai_insights" ADD CONSTRAINT "ai_insights_pkey" PRIMARY KEY ("insight_id");

-- ----------------------------
-- Triggers structure for table attendance
-- ----------------------------
CREATE TRIGGER "calculate_attendance_hours_trigger" BEFORE INSERT OR UPDATE ON "public"."attendance"
FOR EACH ROW
EXECUTE PROCEDURE "public"."calculate_attendance_hours"();
CREATE TRIGGER "update_attendance_updated_at" BEFORE UPDATE ON "public"."attendance"
FOR EACH ROW
EXECUTE PROCEDURE "public"."update_updated_at_column"();

-- ----------------------------
-- Primary Key structure for table attendance
-- ----------------------------
ALTER TABLE "public"."attendance" ADD CONSTRAINT "attendance_pkey" PRIMARY KEY ("attendance_id");

-- ----------------------------
-- Primary Key structure for table chatbot_logs
-- ----------------------------
ALTER TABLE "public"."chatbot_logs" ADD CONSTRAINT "chatbot_logs_pkey" PRIMARY KEY ("chat_id");

-- ----------------------------
-- Triggers structure for table evaluations
-- ----------------------------
CREATE TRIGGER "auto_predict_on_evaluation" AFTER INSERT ON "public"."evaluations"
FOR EACH ROW
WHEN (((new.status)::text = 'Approved'::text))
EXECUTE PROCEDURE "public"."trigger_performance_prediction"();
CREATE TRIGGER "update_evaluations_updated_at" BEFORE UPDATE ON "public"."evaluations"
FOR EACH ROW
EXECUTE PROCEDURE "public"."update_updated_at_column"();

-- ----------------------------
-- Primary Key structure for table evaluations
-- ----------------------------
ALTER TABLE "public"."evaluations" ADD CONSTRAINT "evaluations_pkey" PRIMARY KEY ("eval_id");

-- ----------------------------
-- Triggers structure for table ojt_records
-- ----------------------------
CREATE TRIGGER "update_ojt_records_updated_at" BEFORE UPDATE ON "public"."ojt_records"
FOR EACH ROW
EXECUTE PROCEDURE "public"."update_updated_at_column"();

-- ----------------------------
-- Primary Key structure for table ojt_records
-- ----------------------------
ALTER TABLE "public"."ojt_records" ADD CONSTRAINT "ojt_records_pkey" PRIMARY KEY ("record_id");

-- ----------------------------
-- Primary Key structure for table system_reports
-- ----------------------------
ALTER TABLE "public"."system_reports" ADD CONSTRAINT "system_reports_pkey" PRIMARY KEY ("report_id");

-- ----------------------------
-- Indexes structure for table users
-- ----------------------------
CREATE INDEX "idx_users_email" ON "public"."users" USING btree (
  "email" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);
CREATE INDEX "idx_users_role" ON "public"."users" USING btree (
  "role" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

-- ----------------------------
-- Uniques structure for table users
-- ----------------------------
ALTER TABLE "public"."users" ADD CONSTRAINT "users_email_key" UNIQUE ("email");

-- ----------------------------
-- Checks structure for table users
-- ----------------------------
ALTER TABLE "public"."users" ADD CONSTRAINT "users_role_check" CHECK (role::text = ANY (ARRAY['Admin'::character varying, 'Coordinator'::character varying, 'Supervisor'::character varying, 'Student'::character varying]::text[]));

-- ----------------------------
-- Primary Key structure for table users
-- ----------------------------
ALTER TABLE "public"."users" ADD CONSTRAINT "users_pkey" PRIMARY KEY ("user_id");

-- ----------------------------
-- Foreign Keys structure for table ai_insights
-- ----------------------------
ALTER TABLE "public"."ai_insights" ADD CONSTRAINT "ai_insights_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."users" ("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Keys structure for table attendance
-- ----------------------------
ALTER TABLE "public"."attendance" ADD CONSTRAINT "attendance_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."users" ("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "public"."attendance" ADD CONSTRAINT "attendance_verified_by_fkey" FOREIGN KEY ("verified_by") REFERENCES "public"."users" ("user_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Keys structure for table chatbot_logs
-- ----------------------------
ALTER TABLE "public"."chatbot_logs" ADD CONSTRAINT "chatbot_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users" ("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Keys structure for table evaluations
-- ----------------------------
ALTER TABLE "public"."evaluations" ADD CONSTRAINT "evaluations_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "public"."users" ("user_id") ON DELETE NO ACTION ON UPDATE NO ACTION;
ALTER TABLE "public"."evaluations" ADD CONSTRAINT "evaluations_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."users" ("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "public"."evaluations" ADD CONSTRAINT "evaluations_supervisor_id_fkey" FOREIGN KEY ("supervisor_id") REFERENCES "public"."users" ("user_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Keys structure for table ojt_records
-- ----------------------------
ALTER TABLE "public"."ojt_records" ADD CONSTRAINT "ojt_records_coordinator_id_fkey" FOREIGN KEY ("coordinator_id") REFERENCES "public"."users" ("user_id") ON DELETE RESTRICT ON UPDATE NO ACTION;
ALTER TABLE "public"."ojt_records" ADD CONSTRAINT "ojt_records_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "public"."users" ("user_id") ON DELETE CASCADE ON UPDATE NO ACTION;
ALTER TABLE "public"."ojt_records" ADD CONSTRAINT "ojt_records_supervisor_id_fkey" FOREIGN KEY ("supervisor_id") REFERENCES "public"."users" ("user_id") ON DELETE RESTRICT ON UPDATE NO ACTION;

-- ----------------------------
-- Foreign Keys structure for table system_reports
-- ----------------------------
ALTER TABLE "public"."system_reports" ADD CONSTRAINT "system_reports_generated_by_fkey" FOREIGN KEY ("generated_by") REFERENCES "public"."users" ("user_id") ON DELETE RESTRICT ON UPDATE NO ACTION;
