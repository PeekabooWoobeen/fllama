# Function calling example using pydantic models.
import datetime
import importlib
import json
from enum import Enum
from typing import Optional, Union

import requests
from pydantic import BaseModel, Field
from pydantic_models_to_grammar import (add_run_method_to_dynamic_model, convert_dictionary_to_pydantic_model,
                                        create_dynamic_model_from_function, generate_gbnf_grammar_and_documentation)


# Function to get completion on the llama.cpp server with grammar.
def create_completion(prompt, grammar):
    headers = {"Content-Type": "application/json"}
    data = {"prompt": prompt, "grammar": grammar}

    response = requests.post("http://127.0.0.1:8080/completion", headers=headers, json=data)
    data = response.json()

    print(data["content"])
    return data["content"]


# A function for the agent to send a message to the user.
class SendMessageToUser(BaseModel):
    """
    Send a message to the User.
    """
    chain_of_thought: str = Field(..., description="Your chain of thought while sending the message.")
    message: str = Field(..., description="Message you want to send to the user.")

    def run(self):
        print(self.message)


# Enum for the calculator tool.
class MathOperation(Enum):
    ADD = "add"
    SUBTRACT = "subtract"
    MULTIPLY = "multiply"
    DIVIDE = "divide"


# Simple pydantic calculator tool for the agent that can add, subtract, multiply, and divide. Docstring and description of fields will be used in system prompt.
class Calculator(BaseModel):
    """
    Perform a math operation on two numbers.
    """
    number_one: Union[int, float] = Field(..., description="First number.")
    operation: MathOperation = Field(..., description="Math operation to perform.")
    number_two: Union[int, float] = Field(..., description="Second number.")

    def run(self):
        if self.operation == MathOperation.ADD:
            return self.number_one + self.number_two
        elif self.operation == MathOperation.SUBTRACT:
            return self.number_one - self.number_two
        elif self.operation == MathOperation.MULTIPLY:
            return self.number_one * self.number_two
        elif self.operation == MathOperation.DIVIDE:
            return self.number_one / self.number_two
        else:
            raise ValueError("Unknown operation.")


# Here the grammar gets generated by passing the available function models to generate_gbnf_grammar_and_documentation function. This also generates a documentation usable by the LLM.
# pydantic_model_list is the list of pydanitc models
# outer_object_name is an optional name for an outer object around the actual model object. Like a "function" object with "function_parameters" which contains the actual model object. If None, no outer object will be generated
# outer_object_content is the name of outer object content.
# model_prefix is the optional prefix for models in the documentation. (Default="Output Model")
# fields_prefix is the prefix for the model fields in the documentation. (Default="Output Fields")
gbnf_grammar, documentation = generate_gbnf_grammar_and_documentation(
    pydantic_model_list=[SendMessageToUser, Calculator], outer_object_name="function",
    outer_object_content="function_parameters", model_prefix="Function", fields_prefix="Parameters")

print(gbnf_grammar)
print(documentation)

system_message = "You are an advanced AI, tasked to assist the user by calling functions in JSON format. The following are the available functions and their parameters and types:\n\n" + documentation

user_message = "What is 42 * 42?"
prompt = f"<|im_start|>system\n{system_message}<|im_end|>\n<|im_start|>user\n{user_message}<|im_end|>\n<|im_start|>assistant"

text = create_completion(prompt=prompt, grammar=gbnf_grammar)
# This should output something like this:
# {
#     "function": "calculator",
#     "function_parameters": {
#         "number_one": 42,
#         "operation": "multiply",
#         "number_two": 42
#     }
# }
function_dictionary = json.loads(text)
if function_dictionary["function"] == "calculator":
    function_parameters = {**function_dictionary["function_parameters"]}

    print(Calculator(**function_parameters).run())
    # This should output: 1764


# A example structured output based on pydantic models. The LLM will create an entry for a Book database out of an unstructured text.
class Category(Enum):
    """
    The category of the book.
    """
    Fiction = "Fiction"
    NonFiction = "Non-Fiction"


class Book(BaseModel):
    """
    Represents an entry about a book.
    """
    title: str = Field(..., description="Title of the book.")
    author: str = Field(..., description="Author of the book.")
    published_year: Optional[int] = Field(..., description="Publishing year of the book.")
    keywords: list[str] = Field(..., description="A list of keywords.")
    category: Category = Field(..., description="Category of the book.")
    summary: str = Field(..., description="Summary of the book.")


# We need no additional parameters other than our list of pydantic models.
gbnf_grammar, documentation = generate_gbnf_grammar_and_documentation([Book])

system_message = "You are an advanced AI, tasked to create a dataset entry in JSON for a Book. The following is the expected output model:\n\n" + documentation

text = """The Feynman Lectures on Physics is a physics textbook based on some lectures by Richard Feynman, a Nobel laureate who has sometimes been called "The Great Explainer". The lectures were presented before undergraduate students at the California Institute of Technology (Caltech), during 1961–1963. The book's co-authors are Feynman, Robert B. Leighton, and Matthew Sands."""
prompt = f"<|im_start|>system\n{system_message}<|im_end|>\n<|im_start|>user\n{text}<|im_end|>\n<|im_start|>assistant"

text = create_completion(prompt=prompt, grammar=gbnf_grammar)

json_data = json.loads(text)

print(Book(**json_data))
# An example for parallel function calling with a Python function, a pydantic function model and an OpenAI like function definition.

def get_current_datetime(output_format: Optional[str] = None):
    """
    Get the current date and time in the given format.
    Args:
         output_format: formatting string for the date and time, defaults to '%Y-%m-%d %H:%M:%S'
    """
    if output_format is None:
        output_format = '%Y-%m-%d %H:%M:%S'
    return datetime.datetime.now().strftime(output_format)


# Example function to get the weather
def get_current_weather(location, unit):
    """Get the current weather in a given location"""
    if "London" in location:
        return json.dumps({"location": "London", "temperature": "42", "unit": unit.value})
    elif "New York" in location:
        return json.dumps({"location": "New York", "temperature": "24", "unit": unit.value})
    elif "North Pole" in location:
        return json.dumps({"location": "North Pole", "temperature": "-42", "unit": unit.value})
    else:
        return json.dumps({"location": location, "temperature": "unknown"})


# Here is a function definition in OpenAI style
current_weather_tool = {
    "type": "function",
    "function": {
        "name": "get_current_weather",
        "description": "Get the current weather in a given location",
        "parameters": {
            "type": "object",
            "properties": {
                "location": {
                    "type": "string",
                    "description": "The city and state, e.g. San Francisco, CA",
                },
                "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]},
            },
            "required": ["location"],
        },
    },
}

# Convert OpenAI function definition into pydantic model
current_weather_tool_model = convert_dictionary_to_pydantic_model(current_weather_tool)
# Add the actual function to a pydantic model
current_weather_tool_model = add_run_method_to_dynamic_model(current_weather_tool_model, get_current_weather)

# Convert normal Python function to a pydantic model
current_datetime_model = create_dynamic_model_from_function(get_current_datetime)

tool_list = [SendMessageToUser, Calculator, current_datetime_model, current_weather_tool_model]


gbnf_grammar, documentation = generate_gbnf_grammar_and_documentation(
    pydantic_model_list=tool_list, outer_object_name="function",
    outer_object_content="params", model_prefix="Function", fields_prefix="Parameters", list_of_outputs=True)

system_message = "You are an advanced AI assistant. You are interacting with the user and with your environment by calling functions. You call functions by writing JSON objects, which represent specific function calls.\nBelow is a list of your available function calls:\n\n" + documentation


text = """Get the date and time, get the current weather in celsius in London and solve the following calculation: 42 * 42"""
prompt = f"<|im_start|>system\n{system_message}<|im_end|>\n<|im_start|>user\n{text}<|im_end|>\n<|im_start|>assistant"

text = create_completion(prompt=prompt, grammar=gbnf_grammar)

json_data = json.loads(text)

print(json_data)
# Should output something like this:
# [{'function': 'get_current_datetime', 'params': {'output_format': '%Y-%m-%d %H:%M:%S'}}, {'function': 'get_current_weather', 'params': {'location': 'London', 'unit': 'celsius'}}, {'function': 'Calculator', 'params': {'number_one': 42, 'operation': 'multiply', 'number_two': 42}}]


for call in json_data:
    if call["function"] == "Calculator":
        print(Calculator(**call["params"]).run())
    elif call["function"] == "get_current_datetime":
        print(current_datetime_model(**call["params"]).run())
    elif call["function"] == "get_current_weather":
        print(current_weather_tool_model(**call["params"]).run())
# Should output something like this:
# 2024-01-14 13:36:06
# {"location": "London", "temperature": "42", "unit": "celsius"}
# 1764
