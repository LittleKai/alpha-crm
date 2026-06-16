class A { Future<int> get exitCode => Future.value(0); } void main() { A? a; a?.exitCode.then((v) => print(v)); print('Done'); }
