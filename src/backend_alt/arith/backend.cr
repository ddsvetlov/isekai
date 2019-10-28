require "./req_factory"
require "../../common/dfg"

private def zip_map (left, right)
    raise "Sizes differ" unless left.size == right.size
    return typeof(left).new(left.size) { |i| yield left[i], right[i] }
end

module Isekai::AltBackend::Arith

struct Backend
    private alias JoinedRequest = RequestFactory::JoinedRequest
    private alias SplitRequest = RequestFactory::SplitRequest

    @req_factory : RequestFactory
    @cache_joined = {} of UInt64 => JoinedRequest
    @cache_split = {} of UInt64 => SplitRequest

    def initialize (@req_factory)
    end

    def visit_dependencies (expr : DFGExpr) : Nil
        case expr
        when InputBase, Constant
            # no dependencies
        when Conditional
            yield expr.@cond
            yield expr.@valtrue
            yield expr.@valfalse
        when BinaryOp
            yield expr.@left
            yield expr.@right
        when UnaryOp
            yield expr.@expr
        else
            raise "Not implemented for #{expr.class}"
        end
    end

    private def lay_down_zero_extend (expr : DFGExpr, to new_width : Int32) : JoinedRequest | SplitRequest
        old_width = expr.@bitwidth.@width
        joined_req, split_req = get_both(expr)
        if split_req
            return SplitRequest.new(new_width) do |i|
                split_req[i]? || @req_factory.bake_const(0, width: 1)
            end
        end

        result = @req_factory.joined_zero_extend(joined_req.not_nil!, to: new_width)
        if result.is_a? SplitRequest
            cache_split! expr, result.first(old_width)
        end
        result
    end

    private def zero_extend_to_joined (expr : DFGExpr, to new_width : Int32) : JoinedRequest
        result = lay_down_zero_extend(expr, to: new_width)
        if result.is_a? SplitRequest
            result = @req_factory.split_to_joined(result)
            old_width = expr.@bitwidth.@width
            cache_joined! expr, @req_factory.joined_trunc(result, to: old_width)
        end
        result
    end

    private def subtract_for_cmp (left : JoinedRequest, right : JoinedRequest) : SplitRequest
        result = @req_factory.joined_sub(left, right, force_correct: true)
        if result.is_a? JoinedRequest
            @req_factory.joined_to_split(result)
        else
            result
        end
    end

    private def lay_down_cmp_lt (left : DFGExpr, right : DFGExpr) : JoinedRequest
        old_width = left.@bitwidth.@width
        new_width = old_width + 1
        ext_left_req  = zero_extend_to_joined(left, to: new_width)
        ext_right_req = zero_extend_to_joined(right, to: new_width)
        diff_bits = subtract_for_cmp(ext_left_req, ext_right_req)
        return diff_bits.last
    end

    private def lay_down_sign_extend (left : SplitRequest, to new_width : Int32) : SplitRequest
        return SplitRequest.new(new_width) do |i|
            left[i]? || left.last
        end
    end

    private def lay_down_cmp_lt_signed (left : SplitRequest, right : SplitRequest) : JoinedRequest
        new_width = left.size + 1

        ext_left = lay_down_sign_extend(left, to: new_width)
        ext_right = lay_down_sign_extend(right, to: new_width)
        diff_bits = subtract_for_cmp(
            @req_factory.split_to_joined(ext_left),
            @req_factory.split_to_joined(ext_right))
        return diff_bits.last
    end

    def has_cached? (expr : DFGExpr)
        key = expr.object_id
        @cache_joined.has_key?(key) || @cache_split.has_key?(key)
    end

    private def get_joined (expr : DFGExpr) : JoinedRequest
        key = expr.object_id
        @cache_joined.fetch(key) do
            @cache_joined[key] = @req_factory.split_to_joined(@cache_split[key])
        end
    end

    private def get_split (expr : DFGExpr) : SplitRequest
        key = expr.object_id
        @cache_split.fetch(key) do
            @cache_split[key] = @req_factory.joined_to_split(@cache_joined[key])
        end
    end

    private def get_both (expr : DFGExpr) : {JoinedRequest?, SplitRequest?}
        key = expr.object_id
        return {@cache_joined[key]?, @cache_split[key]?}
    end

    private struct ProofOfCache
    end

    private def cache_joined! (expr : DFGExpr, request : JoinedRequest) : ProofOfCache
        @cache_joined[expr.object_id] = request
        return ProofOfCache.new
    end

    private def cache_split! (expr : DFGExpr, request : SplitRequest) : ProofOfCache
        @cache_split[expr.object_id] = request
        return ProofOfCache.new
    end

    private def cache_either! (expr : DFGExpr, request : JoinedRequest | SplitRequest) : ProofOfCache
        if request.is_a? JoinedRequest
            cache_joined! expr, request
        else
            cache_split! expr, request
        end
    end

    def lay_down_and_cache (expr : DFGExpr) : ProofOfCache
        case expr
        when InputBase
            case expr.@which
            when .input?
                return cache_joined! expr, @req_factory.bake_input(expr.@idx)
            when .nizk_input?
                return cache_joined! expr, @req_factory.bake_nizk_input(expr.@idx)
            else
                raise "unreachable"
            end

        when Constant
            return cache_joined! expr, @req_factory.bake_const(
                expr.@value.to_u64!.to_u128,
                width: expr.@bitwidth.@width)

        when Conditional
            cond = get_joined(expr.@cond)
            valtrue = get_joined(expr.@valtrue)
            valfalse = get_joined(expr.@valfalse)
            return cache_joined! expr, @req_factory.joined_cond(cond, valtrue, valfalse)

        when Add
            left = get_joined(expr.@left)
            right = get_joined(expr.@right)
            return cache_joined! expr, @req_factory.joined_add(left, right)

        when Subtract
            left = get_joined(expr.@left)
            right = get_joined(expr.@right)
            return cache_either! expr, @req_factory.joined_sub(left, right)

        when Multiply
            left = get_joined(expr.@left)
            right = get_joined(expr.@right)
            return cache_joined! expr, @req_factory.joined_mul(left, right)

        when Xor
            left = get_split(expr.@left)
            right = get_split(expr.@right)
            return cache_split!(expr, zip_map(left, right) { |a, b| @req_factory.joined_add(a, b) })

        when BitAnd
            left = get_split(expr.@left)
            right = get_split(expr.@right)
            return cache_split!(expr, zip_map(left, right) { |a, b| @req_factory.joined_mul(a, b) })

        when BitOr
            left = get_split(expr.@left)
            right = get_split(expr.@right)
            return cache_split!(expr, zip_map(left, right) { |a, b| @req_factory.joined_or_1bit(a, b) })

        when LeftShift
            left_joined, left_split = get_both(expr.@left)
            right = get_joined(expr.@right)
            shift = right.as_constant
            raise "Not yet implemented: left shift with non-const right operand" unless shift

            width = expr.@bitwidth.@width

            if left_joined
                factor = (shift >= width) ? 0_u128 : (1_u128 << shift)
                c = cache_joined! expr, @req_factory.joined_mul_const(factor, left_joined)
            end
            if left_split
                c = cache_split!(expr, SplitRequest.new(width) do |i|
                    i < shift ? @req_factory.bake_const(0, width: 1) : left_split[i - shift]
                end)
            end
            return c.not_nil!

        when RightShift
            left = get_split(expr.@left)
            right = get_joined(expr.@right)
            shift = right.as_constant
            raise "Not yet implemented: unsigned right shift with non-const right operand" unless shift

            return cache_joined!(expr, @req_factory.bake_const(0, width: left.size)) if shift >= 64

            return cache_split!(expr, SplitRequest.new(left.size) do |i|
                left[i + shift]? || @req_factory.bake_const(0, width: 1)
            end)

        when SignedRightShift
            left = get_split(expr.@left)
            right = get_joined(expr.@right)
            shift = right.as_constant
            raise "Not yet implemented: signed right shift with non-const right operand" unless shift

            return cache_joined!(expr, @req_factory.bake_const(0, width: left.size)) if shift >= 64

            return cache_split!(expr, SplitRequest.new(left.size) do |i|
                left[i + shift]? || left.last
            end)

        when CmpNEQ
            left = get_joined(expr.@left)
            right = get_joined(expr.@right)
            return cache_joined! expr, @req_factory.joined_cmp_neq(left, right)

        when CmpEQ
            left = get_joined(expr.@left)
            right = get_joined(expr.@right)
            neq = @req_factory.joined_cmp_neq(left, right)
            return cache_joined! expr, @req_factory.joined_add_const(1, neq)

        when CmpLT
            left = get_joined(expr.@left)
            right = get_joined(expr.@right)
            return cache_joined! expr, lay_down_cmp_lt(expr.@left, expr.@right)

        when CmpLEQ
            left = get_joined(expr.@left)
            right = get_joined(expr.@right)
            not_leq = lay_down_cmp_lt(expr.@right, expr.@left)
            return cache_joined! expr, @req_factory.joined_add_const(1, not_leq)

        when SignedCmpLT
            left = get_split(expr.@left)
            right = get_split(expr.@right)
            return cache_joined! expr, lay_down_cmp_lt_signed(left, right)

        when SignedCmpLEQ
            left = get_split(expr.@left)
            right = get_split(expr.@right)
            not_leq = lay_down_cmp_lt_signed(right, left)
            return cache_joined! expr, @req_factory.joined_add_const(1, not_leq)

        when ZeroExtend
            return cache_either! expr, lay_down_zero_extend(expr.@expr, to: expr.@bitwidth.@width)

        when SignExtend
            arg = get_split(expr.@expr)
            return cache_split! expr, lay_down_sign_extend(arg, to: expr.@bitwidth.@width)

        when Truncate
            req_joined, req_split = get_both(expr.@expr)
            new_width = expr.@bitwidth.@width
            if req_joined
                c = cache_joined! expr, @req_factory.joined_trunc(req_joined, to: new_width)
            end
            if req_split
                c = cache_split! expr, req_split.first(new_width)
            end
            return c.not_nil!

        else
            raise "Not implemented for #{expr.class}"
        end
    end

    def add_output_cached! (expr : DFGExpr) : Nil
        @req_factory.joined_add_output!(get_joined(expr))
    end
end

end
