module d.llvm.backend;

import d.llvm.codegen;
import d.llvm.evaluator;
import d.llvm.datalayout;

import d.ir.symbol;

import llvm.c.core;
import llvm.c.target;
import llvm.c.targetMachine;

final class LLVMBackend {
private:
	CodeGen pass;
	
	LLVMEvaluator evaluator;
	LLVMDataLayout dataLayout;
	
	LLVMTargetMachineRef targetMachine;
	
public:
	import d.context.context, d.semantic.scheduler, d.object;
	this(
		Context context,
		Scheduler scheduler,
		ObjectReference obj,
		string name,
	) {
		LLVMInitializeX86TargetInfo();
		LLVMInitializeX86Target();
		LLVMInitializeX86TargetMC();
		
		import llvm.c.executionEngine;
		LLVMLinkInMCJIT();
		LLVMInitializeX86AsmPrinter();
		
		version(OSX) {
			auto triple = "x86_64-apple-darwin9".ptr;
		} else version (FreeBSD) {
			auto triple = "x86_64-unknown-freebsd".ptr;
		} else {
			auto triple = "x86_64-pc-linux-gnu".ptr;
		}
		
		version(linux) {
			enum Reloc = LLVMRelocMode.PIC;
		} else {
			enum Reloc = LLVMRelocMode.Default;
		}
		
		targetMachine = LLVMCreateTargetMachine(
			LLVMGetFirstTarget(),
			triple,
			"x86-64".ptr,
			"".ptr,
			LLVMCodeGenOptLevel.Default,
			Reloc,
			LLVMCodeModel.Default,
		);
		
		auto td = LLVMCreateTargetDataLayout(targetMachine);
		scope(exit) LLVMDisposeTargetData(td);
		
		pass = new CodeGen(context, scheduler, obj, this, name, td);
		dataLayout = new LLVMDataLayout(pass, pass.targetData);
	}
	
	~this() {
		LLVMDisposeTargetMachine(targetMachine);
	}
	
	auto getPass() {
		return pass;
	}
	
	auto getEvaluator() {
		if (evaluator is null) {
			evaluator = new LLVMEvaluator(pass);
		}
		
		return evaluator;
	}
	
	auto getDataLayout() {
		return dataLayout;
	}
	
	void visit(Module mod) {
		pass.visit(mod);
	}
	
	void visit(Function f) {
		import d.llvm.global;
		GlobalGen(pass).define(f);
	}
	
	private void runLLVMPasses(Module[] modules) {
		foreach(m; modules) {
			pass.visit(m);
		}
		
		import llvm.c.transforms.passManagerBuilder;
		auto pmb = LLVMPassManagerBuilderCreate();
		scope(exit) LLVMPassManagerBuilderDispose(pmb);
		
		uint optLevel = pass.context.config.optLevel;
		if (optLevel == 0) {
			LLVMPassManagerBuilderUseInlinerWithThreshold(pmb, 0);
			LLVMPassManagerBuilderSetOptLevel(pmb, 0);
		} else {
			LLVMPassManagerBuilderUseInlinerWithThreshold(pmb, 100);
			LLVMPassManagerBuilderSetOptLevel(pmb, optLevel);
		}
		
		auto pm = LLVMCreatePassManager();
		scope(exit) LLVMDisposePassManager(pm);
		
		LLVMPassManagerBuilderPopulateModulePassManager(pmb, pm);
		LLVMRunPassManager(pm, pass.dmodule);
	}
	
	void emitObject(Module[] modules, string objFile) {
		runLLVMPasses(modules);
		
		import std.string;
		char* errorPtr;
		auto emitError = LLVMTargetMachineEmitToFile(
			targetMachine,
			pass.dmodule,
			objFile.toStringz(),
			LLVMCodeGenFileType.Object,
			&errorPtr,
		);
		
		if (emitError) {
			scope(exit) LLVMDisposeMessage(errorPtr);
			
			import std.c.string, std.stdio;
			writeln(errorPtr[0 .. strlen(errorPtr)]);
			
			assert(0, "Fail to emit object file ! Exiting...");
		}
	}
	
	void emitAsm(Module[] modules, string filename) {
		runLLVMPasses(modules);
		
		import std.string;
		char* errorPtr;
		auto printError = LLVMTargetMachineEmitToFile(
			targetMachine,
			pass.dmodule,
			filename.toStringz(),
			LLVMCodeGenFileType.Assembly,
			&errorPtr,
		);
		
		if (printError) {
			scope(exit) LLVMDisposeMessage(errorPtr);
			
			import std.c.string, std.stdio;
			writeln(errorPtr[0 .. strlen(errorPtr)]);
			
			assert(0, "Failed to output assembly file! Exiting...");
		}
	}
	
	void emitLLVMAsm(Module[] modules, string filename) {
		runLLVMPasses(modules);
		
		import std.string;
		char* errorPtr;
		auto printError = LLVMPrintModuleToFile(
			pass.dmodule,
			filename.toStringz(),
			&errorPtr,
		);
		
		if (printError) {
			scope(exit) LLVMDisposeMessage(errorPtr);
			
			import std.c.string, std.stdio;
			writeln(errorPtr[0 .. strlen(errorPtr)]);
			
			assert(0, "Failed to output LLVM assembly file! Exiting...");
		}
	}
	
	void emitLLVMBitcode(Module[] modules, string filename) {
		runLLVMPasses(modules);
		
		import llvm.c.bitWriter;
		import std.string;
		auto error = LLVMWriteBitcodeToFile(pass.dmodule, filename.toStringz());
		if (error) {
			assert(0, "Failed to output LLVM bitcode file! Exiting...");
		}
	}
	
	void link(string objFile, string executable) {
		import std.algorithm, std.array;
		auto params = pass.context.config.linkerPaths
			.map!(path => " -L" ~ (cast(string) path))
			.join();
		
		import std.process;
		auto linkCommand = "gcc -o "
			~ escapeShellFileName(executable) ~ " "
			~ escapeShellFileName(objFile)
			~ params ~ " -lsdrt -lphobos -lpthread";
		
		wait(spawnShell(linkCommand));
	}
	
	void runUnittests(Module[] modules) {
		// In a first step, we do all the codegen.
		// We need to do it in a first step so that we can reuse
		// one instance of MCJIT.
		foreach (m; modules) {
			foreach (t; m.tests) {
				import d.llvm.local;
				auto f = LocalGen(pass, Mode.Eager).declare(t);
			}
		}
		
		// Now that we generated the IR, we run the unittests.
		import d.llvm.evaluator;
		auto ee = createExecutionEngine(pass.dmodule);
		
		import llvm.c.executionEngine;
		scope(exit) destroyExecutionEngine(ee, pass.dmodule);
		
		foreach (m; modules) {
			foreach (t; m.tests) {
				import d.llvm.local;
				auto f = LocalGen(pass, Mode.Eager).declare(t);
				auto result = LLVMRunFunction(ee, f, 0, null);
				
				// TODO: Check the return value and pretty print.
				// Right now, unittest will crash on assert fail,
				// so we are doing just fine :)
				LLVMDisposeGenericValue(result);
			}
		}
	}
}
