from langchain.document_loaders import UnstructuredFileLoader, UnstructuredURLLoader

loader = UnstructuredFileLoader("main.png")
docs = loader.load()
print(f">>>\n{docs[0].page_content}<<<\n")

loader = UnstructuredFileLoader("main.jpeg")
docs = loader.load()
print(f">>>\n{docs[0].page_content}<<<\n")
