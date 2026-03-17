import ollama
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Official OJT Competencies from seed_competencies.sql
COMPETENCIES = [
    "Software Development",
    "Machine Learning Engineering",
    "IT-Related Research",
    "User Experience / UI Design",
    "Information Security Analysis",
    "Networking",
    "Technical Support",
    "Data Analysis",
    "Customer Service",
    "Data Entry and Management",
    "Office Work"
]

def suggest_competency(task_description: str) -> str:
    """
    Use Ollama to suggest a primary competency from the official list based on a task description.
    
    Args:
        task_description: The description of the task performed by the student.
        
    Returns:
        The title of the most fitting competency.
    """
    if not task_description or len(task_description.strip()) < 5:
        return "Office Work" # Default fallback
        
    prompt = f"""
You are an expert OJT coordinator. Analyze the following OJT task description and suggest the SINGLE MOST fitting competency from the official list below.
Only return the exact competency name from the list, nothing else.

OFFICIAL COMPETENCIES:
{", ".join(COMPETENCIES)}

TASK DESCRIPTION:
{task_description}

SUGGESTED COMPETENCY:
"""
    try:
        # Use a low temperature for deterministic extraction
        response = ollama.chat(
            model="gemma2:2b",
            messages=[{"role": "user", "content": prompt}],
            options={
                "temperature": 0.1,
                "num_predict": 25,
                "top_p": 0.9
            }
        )
        
        raw_suggestion = response["message"]["content"].strip()
        logger.info(f"[COMPETENCY_HANDLER] Suggested: {raw_suggestion}")
        
        # Match against official list (case-insensitive)
        for comp in COMPETENCIES:
            if comp.lower() in raw_suggestion.lower():
                return comp
                
        # If no exact match, try keyword matching
        task_lower = task_description.lower()
        if "code" in task_lower or "app" in task_lower or "program" in task_lower:
            return "Software Development"
        if "ui" in task_lower or "design" in task_lower or "figma" in task_lower:
            return "User Experience / UI Design"
        if "network" in task_lower or "router" in task_lower or "server" in task_lower:
            return "Networking"
        if "excel" in task_lower or "data" in task_lower:
            return "Data Entry and Management"
            
        return "Office Work" # Global fallback
        
    except Exception as e:
        logger.error(f"[COMPETENCY_HANDLER] Error: {e}")
        return "Office Work"

if __name__ == "__main__":
    # Test
    test_desc = "Developed a new feature for the mobile app using Flutter and integrated it with the backend API."
    print(f"Task: {test_desc}")
    print(f"Suggestion: {suggest_competency(test_desc)}")
    
    test_desc = "Cleaned the office and organized the files."
    print(f"Task: {test_desc}")
    print(f"Suggestion: {suggest_competency(test_desc)}")
