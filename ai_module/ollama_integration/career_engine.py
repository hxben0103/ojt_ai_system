def analyze_career_path(student_data: dict) -> dict:
    """
    Analyzes student OJT competencies and matches them to 4 core IT tracks.
    Returns match percentages and skill gaps.
    """
    if not student_data or "competencies" not in student_data:
        return None
        
    competencies = student_data.get("competencies", {})
    
    # 4 Core Industrial Tracks
    tracks = {
        "Software Engineering": ["software_development", "it_related_research", "user_experience_ui_design"],
        "AI & Data Science": ["machine_learning_engineering", "data_analysis"],
        "Infrastructure & Security": ["information_security_analysis", "networking"],
        "Technical Support & Ops": ["technical_support", "customer_service", "office_work", "data_entry_and_management"]
    }
    
    # Let's assume 40 hours is a solid baseline for a specific competency to be considered "proficient"
    TARGET_HOURS_PER_SKILL = 40.0
    
    results = {}
    skill_gaps = []
    
    for track_name, skills in tracks.items():
        track_total_hours = 0.0
        track_target = len(skills) * TARGET_HOURS_PER_SKILL
        
        for skill in skills:
            # handle possible naming variations
            hours = float(competencies.get(skill, 0.0))
            if hours == 0.0 and skill == "data_entry_and_management":
                hours = float(competencies.get("data_entry_management", 0.0))
            if hours == 0.0 and skill == "user_experience_ui_design":
                hours = float(competencies.get("ux_ui_design", 0.0))
                
            track_total_hours += hours
            
            # identify skill gaps (less than 50% of target)
            if hours < (TARGET_HOURS_PER_SKILL * 0.5):
                skill_gaps.append({
                    "skill": skill.replace("_", " ").title(),
                    "current_hours": hours,
                    "target_hours": TARGET_HOURS_PER_SKILL,
                    "track": track_name
                })
                
        # Calculate track percentage (capped at 100%)
        match_percentage = min(100.0, (track_total_hours / track_target) * 100) if track_target > 0 else 0.0
        results[track_name] = {
            "match_percentage": round(match_percentage, 1),
            "total_hours": round(track_total_hours, 1)
        }
        
    return {
        "track_matches": results,
        "skill_gaps": sorted(skill_gaps, key=lambda x: x["current_hours"])
    }

def generate_career_briefing(student_data: dict) -> str:
    """
    Generates a natural language system prompt prefix for the LLM based on career analysis.
    """
    analysis = analyze_career_path(student_data)
    if not analysis:
        return ""
        
    matches = analysis["track_matches"]
    gaps = analysis["skill_gaps"]
    
    # Find top tracking 
    top_track = max(matches.items(), key=lambda x: x[1]["match_percentage"])
    
    prompt = f"[SYSTEM INSTRUCTION: The user you are talking to is currently doing their IT OJT.]\n"
    prompt += f"Based on their uploaded database metrics, their strongest career aptitude is **{top_track[0]}** with an {top_track[1]['match_percentage']}% match based on {top_track[1]['total_hours']} logged hours in related competencies.\n"
    
    prompt += "\nHere is the breakdown of their career alignment:\n"
    for track, data in matches.items():
        if track != top_track[0]:
            prompt += f"- {track}: {data['match_percentage']}% match\n"
            
    if gaps:
        prompt += "\nTo improve their employability or shift tracks, they have the following skill gaps (<20 hours logged so far):\n"
        for gap in gaps[:4]: # only show top 4 to avoid overwhelming the prompt
            prompt += f"- {gap['skill']} ({gap['current_hours']} hrs)\n"
            
    prompt += "\n[SYSTEM INSTRUCTION: Only bring up this career alignment data if the user explicitly asks about what career they are suited for, what jobs to take, or asks for an evaluation of their skills. Do not blindly dump this text. Incorporate it naturally as if you computed it.]\n\n"
    return prompt
