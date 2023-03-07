from langchain.document_loaders import UnstructuredFileLoader, UnstructuredURLLoader

# loader = UnstructuredFileLoader("layout-parser-paper.pdf")
# docs = loader.load()
# print(f">>>\n{docs}<<<\n")

loader = UnstructuredFileLoader("main.pdf")
docs = loader.load()
print(f">>>\n{docs}<<<\n")

# loader = UnstructuredFileLoader("character.png")
# docs = loader.load()
# print(f">>>\n{docs}<<<\n")

from pytesseract import pytesseract

print(pytesseract.image_to_string("main.png"))
